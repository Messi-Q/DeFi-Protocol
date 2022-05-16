// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

interface IERC20Mintable {
    function mint(uint256 amount) external;

    function mint(address beneficiary, uint256 amount) external;
}
