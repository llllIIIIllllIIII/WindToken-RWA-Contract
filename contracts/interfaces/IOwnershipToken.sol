// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IOwnershipToken is IERC20Metadata {
    event MinterUpdated(address indexed newMinter);

    /// @dev 初始化代幣，綁定對應的專案與管理員。
    function initialize(string calldata name_, string calldata symbol_, uint8 decimals_, address project, address admin)
        external;

    /// @dev 回傳擁有鑄造權的專案合約。
    function project() external view returns (address);

    /// @dev 當前的授權鑄造者。
    function minter() external view returns (address);

    /// @dev 更新鑄造權限，僅限管理員。
    function setMinter(address newMinter) external;

    /// @dev 為指定地址鑄造代幣。
    function mint(address to, uint256 amount) external;

    /// @dev 由專案或被授權者銷毀代幣。
    function burn(address from, uint256 amount) external;
}
