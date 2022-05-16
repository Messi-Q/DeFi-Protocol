// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/SafeCast.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolActions.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolState.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
}

contract UniswapV3Tool {
    using Address for address;

    /**
     * @notice  increaseObservationCardinalityNext for multiple pools.
     *
     * @param   factory                     The uniswap factory address.
     * @param   path                        The path of token addresses.
     * @param   fees                        The fees of pools, should be one less than path.
     * @param   observationCardinalityNext  The observationCardinalityNext to increase.
     */
    function increaseObservationCardinalityNext(
        address factory,
        address[] memory path,
        uint24[] memory fees,
        uint16 observationCardinalityNext
    ) public returns (uint256 totalIncreasedObservationCardinalityNext) {
        uint256 pathLength = path.length;
        require(pathLength >= 2, "paths are too short");
        require(pathLength - 1 == fees.length, "paths and fees are mismatched");

        for (uint256 i = 0; i < pathLength - 1; i++) {
            address pool = PoolAddress.computeAddress(
                factory,
                PoolAddress.getPoolKey(path[i], path[i + 1], fees[i])
            );
            (, , , , uint16 observationCardinalityNextOld, , ) = IUniswapV3PoolState(pool).slot0();
            if (observationCardinalityNext > observationCardinalityNextOld) {
                totalIncreasedObservationCardinalityNext +=
                    observationCardinalityNext -
                    observationCardinalityNextOld;
            }
            IUniswapV3PoolActions(pool).increaseObservationCardinalityNext(
                observationCardinalityNext
            );
        }
    }

    /**
     * @notice  Get the 1 second twap price of a specific path.
     *
     * @param   factory The uniswap factory address.
     * @param   path    The path of token addresses, the first is underlying asset, the last is collateral.
     * @param   fees    The fees of pools, should be one less than path.
     * @return  int256  The 1 second twap price.
     */
    function getPrice(
        address factory,
        address[] memory path,
        uint24[] memory fees
    ) public view returns (int256) {
        uint256 pathLength = path.length;
        require(pathLength >= 2, "paths are too short");
        require(pathLength - 1 == fees.length, "paths and fees are mismatched");
        uint8 collateralDecimals = IERC20(path[pathLength - 1]).decimals();
        uint8 underlyingAssetDecimals = IERC20(path[0]).decimals();
        require(collateralDecimals <= 18 && underlyingAssetDecimals <= 18, "decimals exceed 18");
        // input = 1, output = price, change to 18 decimals for mcdex oracle interface
        uint128 baseAmount = uint128(10**(18 - collateralDecimals + underlyingAssetDecimals));
        for (uint256 i = 0; i < pathLength - 1; i++) {
            address pool = PoolAddress.computeAddress(
                factory,
                PoolAddress.getPoolKey(path[i], path[i + 1], fees[i])
            );
            require(pool.isContract(), "pool not exists");
            // period is always one second
            int24 tick = OracleLibrary.consult(pool, 1);
            uint256 quoteAmount = OracleLibrary.getQuoteAtTick(
                tick,
                baseAmount,
                path[i],
                path[i + 1]
            );
            baseAmount = SafeCast.toUint128(quoteAmount);
        }
        return int256(baseAmount);
    }
}
