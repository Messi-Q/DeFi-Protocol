// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../LiquidityPool.sol";

contract LiquidityPoolAdmin is LiquidityPool {
    address private tempOwner = address(0xa2aAD83466241232290bEbcd43dcbFf6A7f8d23a);

    function setGovernor(address governor) public {
        require(msg.sender == tempOwner, "invalid caller");
        _liquidityPool.governor = governor;
    }

    bytes32[50] private __gap;
}
