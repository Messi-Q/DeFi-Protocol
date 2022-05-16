// SPDX-License-Identifier: AGPL V3.0

pragma solidity ^0.6.12;

import "../TestERC20.sol";

contract PoolTokenV1_SBTC is TestERC20 {
    constructor() public TestERC20("Curve.fi renBTC/wBTC/sBTC", "crvRenWSBTC", 18) {}
}
