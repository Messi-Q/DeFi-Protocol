// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/OrderData.sol";
import "../libraries/Signature.sol";

import "../module/OrderModule.sol";

import "../Type.sol";
import "../Storage.sol";

contract TestOrder is Storage {
    using OrderData for Order;
    using OrderData for bytes;
    using OrderModule for LiquidityPoolStorage;

    constructor() {
        _liquidityPool.perpetualCount = 1;
    }

    function decompress(bytes memory data)
        public
        pure
        returns (Order memory order, bytes memory signature)
    {
        order = data.decodeOrderData();
        signature = data.decodeSignature();
    }

    function orderHash(Order memory order) public pure returns (bytes32) {
        return order.getOrderHash();
    }

    function isCloseOnly(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function isMarketOrder(Order memory order) public pure returns (bool) {
        return order.isMarketOrder();
    }

    function isStopLossOrder(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function isTakeProfitOrder(Order memory order) public pure returns (bool) {
        return order.isCloseOnly();
    }

    function salt(Order memory order) public pure returns (uint64) {
        return order.salt;
    }

    function getSigner(Order memory order, bytes memory signature) public view returns (address) {
        return Signature.getSigner(order.getOrderHash(), signature);
    }

    function validateSignature(Order memory order, bytes memory signature) public view {
        _liquidityPool.validateSignature(order, signature);
    }

    function validateOrder(Order memory order, int256 amount) public view {
        _liquidityPool.validateOrder(order, amount);
    }

    function validateTriggerPrice(Order memory order) public view {
        _liquidityPool.validateTriggerPrice(order);
    }

    function setPositionAmount(address trader, int256 amount) public {
        _liquidityPool.perpetuals[0].marginAccounts[trader].position = amount;
    }

    function compress(
        Order memory testOrder,
        bytes32 r,
        bytes32 s,
        uint8 v,
        uint8 signType
    ) public pure returns (bytes memory compressed) {
        bytes memory p1 = abi.encodePacked(
            testOrder.trader,
            testOrder.broker,
            testOrder.relayer,
            testOrder.referrer,
            testOrder.liquidityPool
        );
        bytes memory p2 = abi.encodePacked(
            testOrder.minTradeAmount,
            testOrder.amount,
            testOrder.limitPrice,
            testOrder.triggerPrice,
            testOrder.chainID
        );
        bytes memory p3 = abi.encodePacked(
            testOrder.expiredAt,
            testOrder.perpetualIndex,
            testOrder.brokerFeeLimit,
            testOrder.flags,
            testOrder.salt,
            v,
            signType
        ); // 64 + 32 + 32 + 32 + 32 + 8 + 8
        bytes memory p4 = abi.encodePacked(r, s);
        compressed = abi.encodePacked(p1, p2, p3, p4);
    }
}
