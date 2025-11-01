// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {IOwnershipToken} from "../interfaces/IOwnershipToken.sol";
import {IWindTurbineProject} from "../interfaces/IWindTurbineProject.sol";

/// @title OwnershipToken
/// @notice 代表專案持分的權益代幣，僅允許授權鑄造者鑄造/銷毀並支援 UUPS 升級。
contract OwnershipToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    IOwnershipToken
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address private _project;
    address private _minter;
    uint8 private _tokenDecimals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc IOwnershipToken
    function initialize(
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address project_,
        address admin_
    ) external override initializer {
        require(project_ != address(0), "OToken: project required");
        require(admin_ != address(0), "OToken: admin required");
        require(bytes(name_).length != 0, "OToken: name required");
        require(bytes(symbol_).length != 0, "OToken: symbol required");

        __ERC20_init(name_, symbol_);
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _tokenDecimals = decimals_;
        _project = project_;
        _minter = project_;

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(UPGRADER_ROLE, admin_);

        emit MinterUpdated(project_);
    }

    /// @inheritdoc IOwnershipToken
    function project() external view override returns (address) {
        return _project;
    }

    /// @inheritdoc IOwnershipToken
    function minter() external view override returns (address) {
        return _minter;
    }

    /// @inheritdoc IOwnershipToken
    function setMinter(address newMinter) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMinter != address(0), "OToken: minter zero");
        _minter = newMinter;
        emit MinterUpdated(newMinter);
    }

    /// @inheritdoc IOwnershipToken
    function mint(address to, uint256 amount) external override {
        require(msg.sender == _minter, "OToken: only minter");
        require(to != address(0), "OToken: to zero");
        require(amount > 0, "OToken: amount zero");
        _mint(to, amount);
    }

    /// @inheritdoc IOwnershipToken
    function burn(address from, uint256 amount) external override {
        if (msg.sender != _minter) {
            if (msg.sender != from) {
                _spendAllowance(from, msg.sender, amount);
            }
        }
        require(from != address(0), "OToken: from zero");
        require(amount > 0, "OToken: amount zero");
        _burn(from, amount);
    }

    /// @dev 使用自訂小數位數，通常為 18。
    function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return _tokenDecimals;
    }

    /// @dev 僅限具備 UPGRADER_ROLE 的帳號可執行升級。
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}

    /// @dev 每次權益代幣轉移後通知專案合約更新持有人狀態。
    function _update(address from, address to, uint256 value) internal override {
        super._update(from, to, value);
        if (_project != address(0)) {
            IWindTurbineProject(_project).onTokenTransfer(from, to);
        }
    }
}
