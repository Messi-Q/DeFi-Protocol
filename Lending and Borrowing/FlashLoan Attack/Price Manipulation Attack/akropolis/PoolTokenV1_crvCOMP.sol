// SPDX-License-Identifier: AGPL V3.0

pragma solidity ^0.6.12;

import "../TestERC20.sol";

contract PoolTokenV1_crvCOMP is TestERC20 {
    constructor() public TestERC20("Curve.fi cDAI/cUSDC", "cDAI+cUSDC", 18) {}
}
