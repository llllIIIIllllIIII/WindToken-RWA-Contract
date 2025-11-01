// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWindTurbineProject} from "../interfaces/IWindTurbineProject.sol";
import {IOwnershipToken} from "../interfaces/IOwnershipToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title WindTurbineProject
/// @notice 管理募資、驗收與收益分潤的核心專案合約。
contract WindTurbineProject is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    IWindTurbineProject
{
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 private constant MIN_CONTRIBUTION = 100 * 1e6; // 100 USDC，USDC 具 6 位小數
    uint256 private constant FUNDING_GOAL_USDC = 1_000_000 * 1e6; // 募資總額 1,000,000 USDC
    uint256 private constant OWNERSHIP_UNIT = 1e18; // 權益代幣 1 單位（假設 18 位小數）

    IERC20 private _stablecoin;
    address private _treasury;
    address private _ownershipToken;
    address private _operator;

    ProjectState private _state;

    uint256 private _fundingGoal;
    uint256 private _contributionRate;
    uint256 private _totalRaised;
    uint256 private _totalDistributed;
    uint256 private _revenueCount;
    uint256 private _pendingDistributions;
    uint256 private _lockedForDistributions;
    bool private _fundraisingFinalized;

    string private _metadataURI;
    string private _commissioningDocsURI;

    mapping(uint256 revenueId => RevenueEvent) private _revenueEvents;
    mapping(address contributor => ContributionInfo) private _investorInfo;
    address[] private _investors;
    EnumerableSet.AddressSet private _tokenHolders;
    mapping(address => uint256) private _claimable;
    mapping(address => uint256) private _stakedBalances;
    uint256 private _totalStaked;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev 由工廠呼叫，設定專案參數並開啟募資狀態。
    function initialize(ProjectConfig calldata config) external initializer {
        require(config.operator != address(0), "Project: operator");
        require(config.treasury != address(0), "Project: treasury");
        require(config.ownershipToken != address(0), "Project: token");
        require(config.stablecoin != address(0), "Project: stablecoin");
        require(config.fundingGoal == FUNDING_GOAL_USDC, "Project: funding goal");
        require(config.contributionRate == OWNERSHIP_UNIT, "Project: rate");

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _stablecoin = IERC20(config.stablecoin);
        _treasury = config.treasury;
        _ownershipToken = config.ownershipToken;
        _operator = config.operator;

        require(IOwnershipToken(config.ownershipToken).project() == address(this), "Project: token project");

        _fundingGoal = FUNDING_GOAL_USDC;
        _contributionRate = OWNERSHIP_UNIT;
        _metadataURI = config.metadataURI;
        _commissioningDocsURI = config.commissioningDocsURI;

        _state = ProjectState.Fundraising;

        _grantRole(DEFAULT_ADMIN_ROLE, config.operator);
        _grantRole(DEFAULT_ADMIN_ROLE, config.treasury);
        _grantRole(OPERATOR_ROLE, config.operator);
        _grantRole(TREASURY_ROLE, config.treasury);
        _grantRole(UPGRADER_ROLE, config.operator);
        _grantRole(UPGRADER_ROLE, config.treasury);
    }

    /// @dev 募資期間允許投資者以穩定幣換取權益代幣。
    function contribute(uint256 amount) external override nonReentrant returns (uint256 mintedPreview) {
        require(_state == ProjectState.Fundraising, "Project: not fundraising");
        require(amount > 0, "Project: amount zero");
        require(amount % MIN_CONTRIBUTION == 0, "Project: step");

        uint256 remaining = _fundingGoal - _totalRaised;
        require(remaining > 0, "Project: goal met");
        require(amount <= remaining, "Project: exceeds goal");

        mintedPreview = _calculateMint(amount);
        require(mintedPreview > 0, "Project: minted zero");

        _stablecoin.safeTransferFrom(msg.sender, address(this), amount);

        ContributionInfo storage info = _investorInfo[msg.sender];
        if (info.totalContributed == 0) {
            _investors.push(msg.sender);
        }
        info.totalContributed += amount;

        _totalRaised += amount;

        emit ContributionReceived(msg.sender, amount, mintedPreview, _totalRaised);

        if (_totalRaised == _fundingGoal) {
            _finalizeFundraising();
        }
    }

    /// @dev 募資尚未結束前允許投資者退回指定金額。
    function withdrawContribution(uint256 amount) external override nonReentrant returns (uint256 refunded) {
        require(_state == ProjectState.Fundraising, "Project: not fundraising");
        require(amount > 0, "Project: amount zero");
        require(amount % MIN_CONTRIBUTION == 0, "Project: step");

        ContributionInfo storage info = _investorInfo[msg.sender];
        require(info.totalContributed >= amount, "Project: insufficient balance");

        info.totalContributed -= amount;
        if (info.totalContributed == 0) {
            info.tokensMinted = 0;
        }

        _totalRaised -= amount;
        refunded = amount;

        _stablecoin.safeTransfer(msg.sender, refunded);

        emit ContributionWithdrawn(msg.sender, refunded, _totalRaised);
    }

    /// @dev 提供前端試算 mint 數量與目標是否達成。
    function previewContribution(uint256 amount)
        external
        view
        override
        returns (uint256 mintAmount, uint256 newTotalRaised, bool fundingGoalMet)
    {
        if (_state != ProjectState.Fundraising) {
            return (0, _totalRaised, true);
        }
        if (amount == 0 || amount % MIN_CONTRIBUTION != 0) {
            return (0, _totalRaised, _totalRaised >= _fundingGoal);
        }
        uint256 remaining = _fundingGoal - _totalRaised;
        if (amount > remaining) {
            amount = remaining;
        }
        mintAmount = _calculateMint(amount);
        newTotalRaised = _totalRaised + amount;
        fundingGoalMet = newTotalRaised >= _fundingGoal;
    }

    /// @dev 募資結束時計算各投資者應得的權益代幣並一次性鑄造。
    function _finalizeFundraising() private {
        require(!_fundraisingFinalized, "Project: finalized");
        _fundraisingFinalized = true;

        IOwnershipToken token = IOwnershipToken(_ownershipToken);
        uint256 investorCount = _investors.length;
        uint256 mintedTotal;
        for (uint256 i = 0; i < investorCount; ++i) {
            address account = _investors[i];
            ContributionInfo storage info = _investorInfo[account];
            if (info.totalContributed == 0) {
                continue;
            }

            uint256 mintAmount = _calculateMint(info.totalContributed);
            if (mintAmount == 0) {
                continue;
            }

            info.tokensMinted = mintAmount;
            token.mint(account, mintAmount);
            mintedTotal += mintAmount;
            _stakeInternal(account, mintAmount);
        }

        _state = ProjectState.Commissioning;
        emit TokensBatchMinted(mintedTotal, _tokenHolders.length());
        emit FundingGoalReached(_fundingGoal, block.timestamp);
    }

    /// @dev 由營運者上傳驗收證明並進入營運狀態。
    function markCommissioned(string calldata proofCid) external override onlyRole(OPERATOR_ROLE) {
        require(_state == ProjectState.Commissioning, "Project: wrong state");
        _commissioningDocsURI = proofCid;
        _state = ProjectState.Active;
        emit CommissioningConfirmed(proofCid, uint64(block.timestamp));
    }

    /// @dev 營運者提交收益並將穩定幣匯入合約等待分潤。
    function reportRevenue(
        uint256 grossAmount,
        uint256 fees,
        string calldata reportCid,
        uint64 periodStart,
        uint64 periodEnd
    ) external override onlyRole(OPERATOR_ROLE) returns (uint256 revenueId) {
        require(_state == ProjectState.Active, "Project: inactive");
        require(grossAmount > 0, "Project: gross zero");
        require(grossAmount >= fees, "Project: fees too high");
        require(periodEnd >= periodStart, "Project: period");

        uint256 netRevenue = grossAmount - fees;

        _stablecoin.safeTransferFrom(msg.sender, address(this), grossAmount);
        if (fees > 0) {
            _stablecoin.safeTransfer(_treasury, fees);
        }

        revenueId = ++_revenueCount;
        _revenueEvents[revenueId] = RevenueEvent({
            recordedAt: uint64(block.timestamp),
            periodStart: periodStart,
            periodEnd: periodEnd,
            grossRevenue: grossAmount,
            fees: fees,
            netRevenue: netRevenue,
            reportCid: reportCid,
            distributed: false
        });

        _pendingDistributions += 1;
        _lockedForDistributions += netRevenue;

        uint256 currentBalance = _stablecoin.balanceOf(address(this));
        require(currentBalance >= _lockedForDistributions, "Project: insufficient balance");

        emit RevenueReported(revenueId, grossAmount, netRevenue, reportCid);
    }

    /// @dev 對指定收益期進行分潤，超出部分補貼金庫。
    function distribute(uint256 revenueId)
        external
        override
        onlyRole(OPERATOR_ROLE)
        nonReentrant
        returns (uint256 distributedAmount)
    {
        RevenueEvent storage record = _revenueEvents[revenueId];
        require(record.recordedAt != 0, "Project: unknown revenue");
        require(!record.distributed, "Project: already distributed");
        require(_state == ProjectState.Active, "Project: inactive");

        uint256 totalStakedSnapshot = _totalStaked;
        require(totalStakedSnapshot > 0, "Project: no staked");

        uint256 netRevenue = record.netRevenue;
        uint256 holderCount = 0;

        address[] memory holders = _tokenHolders.values();
        uint256 holderLen = holders.length;
        require(holderLen > 0, "Project: no holders");
        for (uint256 i = 0; i < holderLen; i++) {
            address investor = holders[i];
            uint256 staked = _stakedBalances[investor];
            if (staked == 0) {
                continue;
            }
            uint256 share = (netRevenue * staked) / totalStakedSnapshot;
            if (share == 0) {
                continue;
            }
            holderCount++;
            distributedAmount += share;
            // 將應得款項記入可領取餘額，由投資人自行 claim
            _claimable[investor] += share;
            emit FundsCredited(investor, share);
        }

        uint256 remainder = netRevenue - distributedAmount;
        if (remainder > 0) {
            _stablecoin.safeTransfer(_treasury, remainder);
        }

        record.distributed = true;
        _pendingDistributions -= 1;
        _lockedForDistributions -= netRevenue;
        _totalDistributed += distributedAmount;

        emit RevenueDistributed(revenueId, distributedAmount, holderCount);
    }

    /// @dev 提領邀請者累積的 USDC。會將該帳戶的 claimable 金額轉給呼叫者並歸零。
    function claim() external override nonReentrant returns (uint256 amount) {
        amount = _claimable[msg.sender];
        require(amount > 0, "Project: nothing to claim");

        _claimable[msg.sender] = 0;
        _stablecoin.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    /// @dev 查詢帳戶可提領的 USDC。
    function claimable(address account) external view override returns (uint256) {
        return _claimable[account];
    }

    /// @dev 募資結束後允許金庫提領剩餘穩定幣（扣除待分潤金額）。
    function withdrawRemainder(address recipient)
        external
        override
        onlyRole(TREASURY_ROLE)
        nonReentrant
        returns (uint256 amountWithdrawn)
    {
        require(recipient != address(0), "Project: recipient");
        require(_state != ProjectState.Fundraising, "Project: fundraising");

        uint256 balance = _stablecoin.balanceOf(address(this));
        if (balance <= _lockedForDistributions) {
            return 0;
        }
        amountWithdrawn = balance - _lockedForDistributions;
        _stablecoin.safeTransfer(recipient, amountWithdrawn);
    }

    /// @dev 回傳對應之權益代幣。
    function ownershipToken() external view override returns (address) {
        return _ownershipToken;
    }

    /// @dev 募資與分潤使用的穩定幣。
    function stablecoin() external view override returns (IERC20) {
        return _stablecoin;
    }

    /// @dev 專案營運者地址。
    function operator() external view override returns (address) {
        return _operator;
    }

    /// @dev 專案金庫地址。
    function treasury() external view override returns (address) {
        return _treasury;
    }

    /// @dev 募資目標金額。
    function fundingGoal() external view override returns (uint256) {
        return _fundingGoal;
    }

    /// @dev 已募資金額。
    function totalRaised() external view override returns (uint256) {
        return _totalRaised;
    }

    /// @dev 已分配給投資人的穩定幣總額。
    function totalDistributed() external view override returns (uint256) {
        return _totalDistributed;
    }

    /// @dev 目前處於質押狀態的權益代幣總量。
    function totalStaked() external view override returns (uint256) {
        return _totalStaked;
    }

    /// @dev 每單位穩定幣可兌換的權益代幣比例。
    function contributionRate() external view override returns (uint256) {
        return _contributionRate;
    }

    /// @dev 專案目前狀態。
    function state() external view override returns (ProjectState) {
        return _state;
    }

    /// @dev 收益事件數量。
    function revenueEventsCount() external view override returns (uint256) {
        return _revenueCount;
    }

    /// @dev 取得收益事件明細。
    function getRevenueEvent(uint256 revenueId) external view override returns (RevenueEvent memory) {
        RevenueEvent storage record = _revenueEvents[revenueId];
        require(record.recordedAt != 0, "Project: unknown revenue");
        return record;
    }

    /// @dev 查詢投資者的累積貢獻與鑄造量。
    function investorInfo(address account) external view override returns (ContributionInfo memory) {
        return _investorInfo[account];
    }

    /// @dev 查詢投資者目前質押中的權益代幣數量。
    function stakedBalance(address account) external view override returns (uint256) {
        return _stakedBalances[account];
    }

    /// @dev 查詢投資者目前可自由轉移（未質押）的權益代幣數量。
    function unstakedBalance(address account) external view override returns (uint256) {
        IOwnershipToken token = IOwnershipToken(_ownershipToken);
        uint256 balance = token.balanceOf(account);
        uint256 staked = _stakedBalances[account];
        if (balance <= staked) {
            return 0;
        }
        return balance - staked;
    }

    /// @dev 是否仍有待分潤的收益事件。
    function hasPendingDistributions() external view override returns (bool) {
        return _pendingDistributions > 0;
    }

    /// @dev 募資最小單位（100 USDC）。
    function minContributionUnit() external pure override returns (uint256) {
        return MIN_CONTRIBUTION;
    }

    /// @dev 權益代幣轉移時由代幣合約回呼，更新持有人清單。
    function onTokenTransfer(address from, address to) external override {
        require(msg.sender == _ownershipToken, "Project: only token");

        IOwnershipToken token = IOwnershipToken(_ownershipToken);
        if (from != address(0)) {
            uint256 balance = token.balanceOf(from);
            require(balance >= _stakedBalances[from], "Project: transfer exceeds unstaked");
            if (balance == 0) {
                _tokenHolders.remove(from);
            }
        }

        if (to != address(0) && token.balanceOf(to) > 0) {
            _tokenHolders.add(to);
        }
    }

    /// @dev 將代幣質押以參與收益分配。
    function stake(uint256 amount) external override nonReentrant {
        require(_fundraisingFinalized, "Project: staking unavailable");
        require(amount > 0, "Project: amount zero");

        IOwnershipToken token = IOwnershipToken(_ownershipToken);
        uint256 balance = token.balanceOf(msg.sender);
        uint256 currentStaked = _stakedBalances[msg.sender];
        require(balance >= currentStaked + amount, "Project: insufficient unstaked");

        _stakeInternal(msg.sender, amount);
    }

    /// @dev 解除代幣質押，解除後需重新質押才可再次累積收益。
    function unstake(uint256 amount) external override nonReentrant {
        require(_fundraisingFinalized, "Project: staking unavailable");
        require(amount > 0, "Project: amount zero");

        uint256 currentStaked = _stakedBalances[msg.sender];
        require(amount <= currentStaked, "Project: insufficient staked");

        _stakedBalances[msg.sender] = currentStaked - amount;
        _totalStaked -= amount;

        emit Unstaked(msg.sender, amount);
    }

    /// @dev 升級邏輯權限由指定角色管控。
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    /// @dev 依照固定比例換算可鑄造的權益代幣數量。
    function _calculateMint(uint256 amount) private pure returns (uint256) {
        return (amount / MIN_CONTRIBUTION) * OWNERSHIP_UNIT;
    }

    /// @dev 共用的質押寫入邏輯。
    function _stakeInternal(address account, uint256 amount) private {
        if (amount == 0) {
            return;
        }
        _stakedBalances[account] += amount;
        _totalStaked += amount;
        emit Staked(account, amount);
    }
}
