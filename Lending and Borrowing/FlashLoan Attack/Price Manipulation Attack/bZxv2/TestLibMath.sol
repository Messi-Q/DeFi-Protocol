// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.4;

import "../libraries/Math.sol";

contract TestLibMath {
    function mostSignificantBit(uint256 x) public pure returns (uint8) {
        return Math.mostSignificantBit(x);
    }

    function sqrt(int256 y) public pure returns (int256) {
        return Math.sqrt(y);
    }
}
