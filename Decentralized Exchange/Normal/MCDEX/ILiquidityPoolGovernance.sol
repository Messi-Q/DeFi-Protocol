// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

interface ILiquidityPoolGovernance {
    function setEmergencyState(uint256 perpetualIndex) external;
}
