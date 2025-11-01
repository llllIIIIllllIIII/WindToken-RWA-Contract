// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWindTurbineProject {
    enum ProjectState {
        Draft,
        Fundraising,
        Commissioning,
        Active,
        Closed
    }

    struct ProjectConfig {
        address operator;
        address stablecoin;
        address treasury;
        address ownershipToken;
        string metadataURI;
        string commissioningDocsURI;
        string tokenName;
        string tokenSymbol;
        uint8 tokenDecimals;
        uint256 fundingGoal;
        uint256 contributionRate;
    }

    struct ContributionInfo {
        uint256 totalContributed;
        uint256 tokensMinted;
    }

    struct RevenueEvent {
        uint64 recordedAt;
        uint64 periodStart;
        uint64 periodEnd;
        uint256 grossRevenue;
        uint256 fees;
        uint256 netRevenue;
        string reportCid;
        bool distributed;
    }

    event ContributionReceived(
        address indexed contributor, uint256 usdcAmount, uint256 tokenAmount, uint256 totalRaised
    );

    event ContributionWithdrawn(address indexed contributor, uint256 usdcAmount, uint256 totalRaised);

    event FundingGoalReached(uint256 goal, uint256 timestamp);

    event CommissioningConfirmed(string proofCid, uint64 timestamp);

    event RevenueReported(uint256 indexed revenueId, uint256 grossRevenue, uint256 netRevenue, string reportCid);

    event RevenueDistributed(uint256 indexed revenueId, uint256 totalDistributed, uint256 holderCount);
    event FundsCredited(address indexed holder, uint256 amount);
    event Claimed(address indexed holder, uint256 amount);

    event TokensBatchMinted(uint256 totalMinted, uint256 holderCount);
    event Staked(address indexed account, uint256 amount);
    event Unstaked(address indexed account, uint256 amount);

    /// Sets up the proxy with operator, treasury, token metadata, and funding parameters.
    function initialize(ProjectConfig calldata config) external;

    /// 讓投資人投入穩定幣並記錄可兌換的權益代幣份額（實際鑄造於募資完成時執行）。
    function contribute(uint256 amount) external returns (uint256 minted);

    /// 允許投資人在募資結束前提領部份或全部出資。
    function withdrawContribution(uint256 amount) external returns (uint256 refunded);

    /// Returns the mint result and fundraising totals without modifying state.
    function previewContribution(uint256 amount)
        external
        view
        returns (uint256 mintAmount, uint256 newTotalRaised, bool fundingGoalMet);

    /// Marks the project commissioned using an IPFS proof and transitions to Active.
    function markCommissioned(string calldata proofCid) external;

    /// Records a revenue event for a period and returns the new revenue id.
    function reportRevenue(
        uint256 grossAmount,
        uint256 fees,
        string calldata reportCid,
        uint64 periodStart,
        uint64 periodEnd
    ) external returns (uint256 revenueId);

    /// Distributes a recorded revenue event to current token holders.
    function distribute(uint256 revenueId) external returns (uint256 totalDistributed);

    /// 查詢指定地址可領取的 USDC 數量（尚未提領）。
    function claimable(address account) external view returns (uint256);

    /// 將累積的 USDC 領出到呼叫者錢包（需先有累積金額）。
    function claim() external returns (uint256 amount);

    /// Sends any unallocated stablecoin to the treasury once fundraising closes.
    function withdrawRemainder(address recipient) external returns (uint256 amountWithdrawn);

    /// 將未質押的權益代幣投入質押，以便參與收益分配。
    function stake(uint256 amount) external;

    /// 解除指定數量的質押，解除後需再質押才能繼續累積收益。
    function unstake(uint256 amount) external;

    /// 專案對應的權益代幣地址。
    function ownershipToken() external view returns (address);

    /// Stablecoin used for contributions and payouts.
    function stablecoin() external view returns (IERC20);

    /// Operator wallet authorized to manage commissioning and revenue events.
    function operator() external view returns (address);

    /// Treasury wallet eligible to collect leftover funds.
    function treasury() external view returns (address);

    /// Funding cap for the campaign denominated in stablecoin.
    function fundingGoal() external view returns (uint256);

    /// Amount of stablecoin raised so far.
    function totalRaised() external view returns (uint256);

    /// Total stablecoin distributed to investors across all revenue events.
    function totalDistributed() external view returns (uint256);

    /// 所有投資人目前處於質押狀態的權益代幣總量。
    function totalStaked() external view returns (uint256);

    /// Current token minting rate expressed as tokens per stablecoin unit.
    function contributionRate() external view returns (uint256);

    /// Lifecycle state driven by fundraising and commissioning milestones.
    function state() external view returns (ProjectState);

    /// Number of revenue events recorded to date.
    function revenueEventsCount() external view returns (uint256);

    /// Full revenue event metadata for off-chain reconciliation.
    function getRevenueEvent(uint256 revenueId) external view returns (RevenueEvent memory);

    /// Aggregated contribution and minted token totals for a specific investor.
    function investorInfo(address account) external view returns (ContributionInfo memory);

    /// 指定投資人目前處於質押狀態的權益代幣數量。
    function stakedBalance(address account) external view returns (uint256);

    /// 指定投資人可自由轉移（未質押）的權益代幣數量。
    function unstakedBalance(address account) external view returns (uint256);

    /// Returns true when a revenue event exists that has not been distributed.
    function hasPendingDistributions() external view returns (bool);

    /// 募資單位（USDC 100 元為一個單位）。
    function minContributionUnit() external view returns (uint256);

    /// 權益代幣轉移時由代幣合約回呼，更新持有人清單。
    function onTokenTransfer(address from, address to) external;
}
