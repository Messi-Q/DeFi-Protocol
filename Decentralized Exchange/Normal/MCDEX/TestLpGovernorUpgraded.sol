// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../governance/LpGovernor.sol";

contract TestLpGovernorUpgraded is LpGovernor {
    uint256 public testValue;

    function upgradePatch(uint256 n) public {
        require(testValue == 0);
        testValue = n;
    }
}
