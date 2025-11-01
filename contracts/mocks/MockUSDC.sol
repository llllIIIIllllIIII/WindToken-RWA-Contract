// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMockUSDC} from "../interfaces/IMockUSDC.sol";

/// @title MockUSDC
/// @notice 簡化後的 USDC 測試代幣，提供水龍頭與管理者鑄造能力。
contract MockUSDC is ERC20, Ownable, IMockUSDC {
    constructor(address initialOwner) ERC20("Mock USDC", "USDC") Ownable(initialOwner) {}

    /// @dev 任何人都可呼叫以便快速取得測試用資金。
    function faucet(address to, uint256 amount) external override {
        _mint(to, amount);
    }

    /// @dev 僅限擁有者可鑄造額外代幣供測試腳本使用。
    function mint(address to, uint256 amount) external override onlyOwner {
        _mint(to, amount);
    }

    /// @dev 支援從被授權者或本人銷毀代幣，模擬清算行為。
    function burn(address from, uint256 amount) external override {
        if (msg.sender != from) {
            uint256 currentAllowance = allowance(from, msg.sender);
            require(currentAllowance >= amount, "MockUSDC: insufficient allowance");
            unchecked {
                _approve(from, msg.sender, currentAllowance - amount);
            }
        }
        _burn(from, amount);
    }

    /// @dev 固定使用六位小數，對齊 USDC 主網設定。
    function decimals() public pure override(ERC20, IERC20Metadata) returns (uint8) {
        return 6;
    }
}
