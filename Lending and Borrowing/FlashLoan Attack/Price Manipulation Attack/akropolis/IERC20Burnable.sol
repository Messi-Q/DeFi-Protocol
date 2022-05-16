// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

interface IERC20Burnable {
    function burn(uint256 amount) external;

    function burnFrom(address sender, uint256 amount) external;
}
