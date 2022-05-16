// SPDX-License-Identifier: AGPL V3.0

pragma solidity ^0.6.12;

import "../TestERC20.sol";

contract PoolTokenV1_yUSD is TestERC20 {
    constructor() public TestERC20("Curve.fi yDAI/yUSDC/yUSDT/yTUSD", "yDAI+yUSDC+yUSDT+yTUSD", 18) {}
}
