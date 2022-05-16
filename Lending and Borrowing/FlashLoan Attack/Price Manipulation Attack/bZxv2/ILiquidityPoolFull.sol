// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./IPerpetual.sol";
import "./ILiquidityPool.sol";
import "./ILiquidityPoolGetter.sol";
import "./ILiquidityPoolGovernance.sol";

interface ILiquidityPoolFull is
    IPerpetual,
    ILiquidityPool,
    ILiquidityPoolGetter,
    ILiquidityPoolGovernance
{}
