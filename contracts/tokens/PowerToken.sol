// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPowerToken} from "../interfaces/IPowerToken.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title PowerToken
/// @notice 專案用收益權代幣，支援 UUPS 升級與可配置鑄造者。
contract PowerToken is Initializable, ERC20Upgradeable, AccessControlUpgradeable, UUPSUpgradeable, IPowerToken {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    address private _project;
    address private _minter;
    uint8 private _tokenDecimals;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev 初始化代幣基本資訊並綁定專案與管理者。
    function initialize(
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address project_,
        address admin_
    ) external initializer {
        require(project_ != address(0), "PowerToken: project required");
        require(admin_ != address(0), "PowerToken: admin required");

        require(bytes(name_).length != 0, "PowerToken: name required");
        require(bytes(symbol_).length != 0, "PowerToken: symbol required");

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

    /// @dev 回傳負責鑄造的專案合約位址。
    function project() public view override returns (address) {
        return _project;
    }

    /// @dev 查詢目前授權鑄造者。
    function minter() public view override returns (address) {
        return _minter;
    }

    /// @dev 僅限管理者可更新鑄造權，方便升級後重新授權。
    function setMinter(address newMinter) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newMinter != address(0), "PowerToken: invalid minter");
        _minter = newMinter;
        emit MinterUpdated(newMinter);
    }

    /// @dev 只有指定鑄造者才能鑄造新代幣。
    function mint(address to, uint256 amount) external override {
        require(msg.sender == _minter, "PowerToken: only minter");
        require(to != address(0), "PowerToken: invalid recipient");
        require(amount > 0, "PowerToken: amount zero");
        _mint(to, amount);
    }

    /// @dev 鑄造者或被授權者可進行銷毀操作。
    function burn(address from, uint256 amount) external override {
        if (msg.sender != _minter) {
            if (msg.sender != from) {
                _spendAllowance(from, msg.sender, amount);
            }
        }
        require(from != address(0), "PowerToken: invalid source");
        require(amount > 0, "PowerToken: amount zero");
        _burn(from, amount);
    }

    /// @dev 以儲存的自訂小數回覆，通常為 18。
    function decimals() public view override(ERC20Upgradeable, IERC20Metadata) returns (uint8) {
        return _tokenDecimals;
    }

    /// @dev 透過角色控管 UUPS 升級權限。
    function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE) {}
}
