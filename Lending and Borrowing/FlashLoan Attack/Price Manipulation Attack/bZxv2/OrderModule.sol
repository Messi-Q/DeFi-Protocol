// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../interface/IAccessControl.sol";

import "../libraries/Utils.sol";
import "../libraries/OrderData.sol";
import "../libraries/SafeMathExt.sol";
import "../libraries/Signature.sol";

import "./MarginAccountModule.sol";
import "./PerpetualModule.sol";

import "../Type.sol";

library OrderModule {
    using SignedSafeMathUpgradeable for int256;
    using SafeCastUpgradeable for int256;
    using SafeMathExt for int256;
    using OrderData for Order;
    using OrderData for uint32;
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    /**
     * @notice Validate that order's signer is granted the trade privilege by order's trader
     * @param liquidityPool The liquidity pool object
     * @param order The order object
     * @param signature The signature
     */
    function validateSignature(
        LiquidityPoolStorage storage liquidityPool,
        Order memory order,
        bytes memory signature
    ) public view {
        bytes32 orderHash = order.getOrderHash();
        address signer = Signature.getSigner(orderHash, signature);
        if (signer != order.trader) {
            bool isAuthorized = IAccessControl(liquidityPool.accessController).isGranted(
                order.trader,
                signer,
                order.flags.useTargetLeverage()
                    ? Constant.PRIVILEGE_TRADE |
                        Constant.PRIVILEGE_DEPOSIT |
                        Constant.PRIVILEGE_WITHDRAW
                    : Constant.PRIVILEGE_TRADE
            );
            require(isAuthorized, "signer is unauthorized");
        }
    }

    /**
     * @notice Validate the order:
     *         1. broker of order = msg.sender
     *         2. relayer of order = tx.origin
     *         3. liquidity pool of order = address(this)
     *         4. perpetual index of order < count of perpetuals
     *         5. trading amount != 0 and has the same sign with amount of order
     *         6. amount of order != 0
     *         7. minimum trading amount of order <= abs(trading amount) <= abs(amount of order)
     *         8. order is not expire
     *         9. chain id of order is correct
     *         10. order is stop loss order and taker profit order at the same time
     * @param liquidityPool The liquidity pool
     * @param order The order
     * @param amount The trading amount of position
     */
    function validateOrder(
        LiquidityPoolStorage storage liquidityPool,
        Order memory order,
        int256 amount
    ) public view {
        // broker / relayer
        require(order.broker == msg.sender, "broker mismatch");
        require(order.relayer == tx.origin, "relayer mismatch");
        // pool / perpetual
        require(order.liquidityPool == address(this), "liquidity pool mismatch");
        require(
            order.perpetualIndex < liquidityPool.perpetualCount,
            "perpetual index out of range"
        );
        // amount
        require(amount != 0 && Utils.hasTheSameSign(amount, order.amount), "invalid amount");
        require(order.amount != 0, "order amount is 0");
        require(amount.abs() >= order.minTradeAmount, "amount is less than min trade amount");
        require(amount.abs() <= order.amount.abs(), "amount exceeds order amount");
        // expire
        require(order.expiredAt >= block.timestamp, "order is expired");
        // chain id
        require(order.chainID == Utils.chainID(), "chainid mismatch");
        // close only
        require(
            !(order.isStopLossOrder() && order.isTakeProfitOrder()),
            "stop-loss order cannot be take-profit"
        );
    }

    /**
     * @notice Validate the trigger price of the order
     *         When position > 0, if stop loss order: index price must <= trigger price,
     *                            if take profit order: index price must >= trigger price.
     *         When position < 0, if stop loss order: index price must >= trigger price,
     *                            if take profit order: index price must <= trigger price
     * @param liquidityPool The liquidity pool
     * @param order The order
     */
    function validateTriggerPrice(LiquidityPoolStorage storage liquidityPool, Order memory order)
        public
        view
    {
        int256 indexPrice = liquidityPool.perpetuals[order.perpetualIndex].getIndexPrice();
        if (
            (order.isStopLossOrder() && order.amount > 0) ||
            (order.isTakeProfitOrder() && order.amount < 0)
        ) {
            // stop-loss + long / take-profit + short
            require(indexPrice >= order.triggerPrice, "trigger price is not reached");
        } else if (
            (order.isStopLossOrder() && order.amount < 0) ||
            (order.isTakeProfitOrder() && order.amount > 0)
        ) {
            // stop-loss + long / take-profit + short
            require(indexPrice <= order.triggerPrice, "trigger price is not reached");
        }
    }
}
