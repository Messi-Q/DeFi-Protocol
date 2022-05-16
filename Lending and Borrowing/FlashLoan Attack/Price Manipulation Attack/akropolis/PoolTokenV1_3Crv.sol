// SPDX-License-Identifier: AGPL V3.0

pragma solidity ^0.6.12;

import "../TestERC20.sol";

contract PoolTokenV1_3Crv is TestERC20 {
    constructor() public TestERC20("Curve.fi DAI/USDC/USDT", "3Crv", 18) {}
}
