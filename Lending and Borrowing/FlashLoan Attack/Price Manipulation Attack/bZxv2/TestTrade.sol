// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";
import "../module/TradeModule.sol";
import "../module/OrderModule.sol";

import "../libraries/OrderData.sol";
import "../libraries/Utils.sol";

import "../Type.sol";

import "./TestLiquidityPool.sol";

contract TestTrade is TestLiquidityPool {
    using OrderData for bytes;
    using PerpetualModule for PerpetualStorage;
    using MarginAccountModule for PerpetualStorage;
    using TradeModule for LiquidityPoolStorage;
    using TradeModule for PerpetualStorage;
    using OrderModule for LiquidityPoolStorage;

    address internal _vault;
    int256 internal _vaultFeeRate;

    constructor() {
        _liquidityPool.creator = address(this);
        _liquidityPool.accessController = address(this);
    }

    function setTargetLeverage(
        uint256 perpetualIndex,
        address account,
        int256 targetLeverage
    ) public {
        _liquidityPool
            .perpetuals[perpetualIndex]
            .marginAccounts[account]
            .targetLeverage = targetLeverage;
    }

    function getAccessController() public view returns (address) {
        return address(this);
    }

    function isGranted(
        address grantor,
        address grantee,
        uint256 privilege
    ) public view returns (bool) {
        return false;
    }

    function _isValid(uint256 privilege) private pure returns (bool) {
        return privilege > 0 && privilege <= Constant.PRIVILEGE_GUARD;
    }

    function getVault() public view returns (address) {
        return _vault;
    }

    function getVaultFeeRate() public view returns (int256) {
        return _vaultFeeRate;
    }

    function setVault(address vault, int256 vaultFeeRate) public {
        _vault = vault;
        _vaultFeeRate = vaultFeeRate;
    }

    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        address referrer,
        uint32 flags
    ) public syncState(false) {
        _liquidityPool.trade(perpetualIndex, trader, amount, limitPrice, referrer, flags);
    }

    function brokerTrade(bytes memory orderData, int256 amount)
        public
        syncState(false)
        returns (int256)
    {
        Order memory order = orderData.decodeOrderData();
        bytes memory signature = orderData.decodeSignature();
        _liquidityPool.validateSignature(order, signature);
        _liquidityPool.validateOrder(order, amount);
        _liquidityPool.validateTriggerPrice(order);
        return
            _liquidityPool.trade(
                order.perpetualIndex,
                order.trader,
                amount,
                order.limitPrice,
                order.referrer,
                order.flags
            );
    }

    function getFees(
        uint256 perpetualIndex,
        address trader,
        address referrer,
        int256 tradeValue,
        bool hasOpened
    )
        public
        view
        returns (
            int256 lpFee,
            int256 operatorFee,
            int256 vaultFee,
            int256 referralRebate
        )
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        (lpFee, operatorFee, vaultFee, referralRebate) = _liquidityPool.getFees(
            perpetual,
            trader,
            referrer,
            tradeValue,
            hasOpened
        );
    }

    function postTrade(
        uint256 perpetualIndex,
        address trader,
        address referrer,
        int256 deltaCash,
        int256 deltaPosition,
        uint32 flags
    ) public returns (int256 lpFee, int256 totalFee) {
        (lpFee, totalFee) = _liquidityPool.postTrade(
            perpetualIndex,
            trader,
            referrer,
            deltaCash,
            deltaPosition,
            flags
        );
    }

    function validatePrice(
        bool isLong,
        int256 price,
        int256 limitPrice
    ) public pure {
        TradeModule.validatePrice(isLong, price, limitPrice);
    }

    function hasOpenedPosition(int256 amount, int256 delta) public pure returns (bool hasOpened) {
        hasOpened = Utils.hasOpenedPosition(amount, delta);
    }

    function getMargin(uint256 perpetualIndex, address trader) public view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getMargin(trader, perpetual.getMarkPrice());
    }

    function liquidateByAMM(
        uint256 perpetualIndex,
        address liquidator,
        address trader
    ) public returns (int256 deltaPosition) {
        deltaPosition = _liquidityPool.liquidateByAMM(perpetualIndex, liquidator, trader);
    }

    function activatePerpetualFor(address trader, uint256 perpetualIndex) public returns (bool) {}
}
