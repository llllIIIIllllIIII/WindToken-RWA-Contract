// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IPowerToken is IERC20Metadata {
    event MinterUpdated(address indexed newMinter);

    /// Initializes token metadata and assigns the project and admin roles.
    function initialize(string calldata name_, string calldata symbol_, uint8 decimals_, address project, address admin)
        external;

    /// Project contract that owns minting rights.
    function project() external view returns (address);

    /// Address currently allowed to mint and burn tokens.
    function minter() external view returns (address);

    /// Updates the authorized minter; callable by the admin role.
    function setMinter(address newMinter) external;

    /// Mints tokens to `to`, reverting if caller is not the minter.
    function mint(address to, uint256 amount) external;

    /// Burns tokens from `from`, enforcing allowance when necessary.
    function burn(address from, uint256 amount) external;
}
