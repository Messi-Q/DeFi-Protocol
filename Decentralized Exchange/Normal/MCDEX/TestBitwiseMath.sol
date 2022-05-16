// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "../libraries/BitwiseMath.sol";

contract TestBitwiseMath {
    function test(uint256 value, uint256 bit) public pure returns (bool) {
        return BitwiseMath.test(value, bit);
    }

    function set(uint256 value, uint256 bit) public pure returns (uint256) {
        return BitwiseMath.set(value, bit);
    }

    function clean(uint256 value, uint256 bit) public pure returns (uint256) {
        return BitwiseMath.clean(value, bit);
    }
}
