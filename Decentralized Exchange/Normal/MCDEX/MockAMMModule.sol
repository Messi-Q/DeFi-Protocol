// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/Math.sol";
import "../libraries/SafeMathExt.sol";

import "../Type.sol";

contract MockAMMPriceEntries {
    using SafeMathExt for int256;

    int256 public price;

    function queryPrice(int256 tradeAmount)
        public
        view
        returns (int256 deltaCash, int256 deltaPosition)
    {
        deltaCash = tradeAmount.wmul(price).neg();
        deltaPosition = tradeAmount;
    }

    function setPrice(int256 expectPrice) public {
        price = expectPrice;
    }
}

library MockAMMModule {
    function queryTradeWithAMM(
        LiquidityPoolStorage storage liquidityPool,
        uint256,
        int256 tradeAmount,
        bool
    ) public view returns (int256 deltaCash, int256 deltaPosition) {
        MockAMMPriceEntries priceHook = MockAMMPriceEntries(liquidityPool.governor);
        return priceHook.queryPrice(tradeAmount);
    }

    function getPoolMargin(LiquidityPoolStorage storage liquidityPool)
        public
        view
        returns (int256, bool)
    {
        return (10000 * 10**18, true);
    }
}
