// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IMockUSDC is IERC20Metadata {
    /// Convenience faucet for local testing; mints directly to recipient.
    function faucet(address to, uint256 amount) external;

    /// Permissioned mint hook for scripts that simulate treasury top-ups.
    function mint(address to, uint256 amount) external;

    /// Burns tokens from `from`, reverting if allowance is insufficient.
    function burn(address from, uint256 amount) external;
}
