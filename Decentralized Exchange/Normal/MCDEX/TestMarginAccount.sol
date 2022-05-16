// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../Storage.sol";
import "../module/MarginAccountModule.sol";
import "../module/PerpetualModule.sol";
import "./TestPerpetual.sol";

contract TestMarginAccount is TestPerpetual {
    using MarginAccountModule for PerpetualStorage;
    using PerpetualModule for PerpetualStorage;

    function getInitialMargin(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getInitialMargin(trader, perpetual.getMarkPrice());
    }

    function getMaintenanceMargin(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getMaintenanceMargin(trader, perpetual.getMarkPrice());
    }

    function getAvailableCash(uint256 perpetualIndex, address trader)
        external
        view
        returns (int256)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getAvailableCash(trader);
    }

    function getPosition(uint256 perpetualIndex, address trader) external view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getPosition(trader);
    }

    function getMargin2(uint256 perpetualIndex, address trader) external view returns (int256) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.getMargin(trader, perpetual.getMarkPrice());
    }

    function isInitialMarginSafe(uint256 perpetualIndex, address trader)
        external
        view
        returns (bool)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.isInitialMarginSafe(trader, perpetual.getMarkPrice());
    }

    function isMaintenanceMarginSafe(uint256 perpetualIndex, address trader)
        external
        view
        returns (bool)
    {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.isMaintenanceMarginSafe(trader, perpetual.getMarkPrice());
    }

    function isEmptyAccount(uint256 perpetualIndex, address trader) external view returns (bool) {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        return perpetual.isEmptyAccount(trader);
    }

    function updateMargin(
        uint256 perpetualIndex,
        address trader,
        int256 deltaPosition,
        int256 deltaCash
    ) external {
        PerpetualStorage storage perpetual = _liquidityPool.perpetuals[perpetualIndex];
        perpetual.updateMargin(trader, deltaPosition, deltaCash);
    }
}
