// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "./interface/ILiquidityPool.sol";

import "./module/AMMModule.sol";
import "./module/LiquidityPoolModule.sol";
import "./module/PerpetualModule.sol";

import "./Getter.sol";
import "./Governance.sol";
import "./LibraryEvents.sol";
import "./Perpetual.sol";
import "./Storage.sol";
import "./Type.sol";

contract LiquidityPool is Storage, Perpetual, Getter, Governance, LibraryEvents, ILiquidityPool {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.Bytes32Set;
    using SafeCastUpgradeable for uint256;
    using PerpetualModule for PerpetualStorage;
    using LiquidityPoolModule for LiquidityPoolStorage;
    using AMMModule for LiquidityPoolStorage;

    receive() external payable {
        revert("contract does not accept ether");
    }

    /**
     * @notice  Initialize the liquidity pool and set up its configuration
     *
     * @param   operator                The address of operator which should be current pool creator.
     * @param   collateral              The address of collateral token.
     * @param   collateralDecimals      The decimals of collateral token, to support token without decimals interface.
     * @param   governor                The address of governor, who is able to call governance methods.
     * @param   initData                A bytes array contains data to initialize new created liquidity pool.
     */
    function initialize(
        address operator,
        address collateral,
        uint256 collateralDecimals,
        address governor,
        bytes calldata initData
    ) external override initializer {
        _liquidityPool.initialize(
            _msgSender(),
            collateral,
            collateralDecimals,
            operator,
            governor,
            initData
        );
    }

    /**
     * @notice  Create new perpetual of the liquidity pool.
     *          The operator can create perpetual only when the pool is not running or isFastCreationEnabled is true.
     *          Otherwise a perpetual can only be create by governor (say, through voting).
     *
     * @param   oracle              The oracle's address of the perpetual.
     * @param   baseParams          The base parameters of the perpetual, see whitepaper for details.
     * @param   riskParams          The risk parameters of the perpetual,
     *                              Must be within range [minRiskParamValues, maxRiskParamValues].
     * @param   minRiskParamValues  The minimum values of risk parameters.
     * @param   maxRiskParamValues  The maximum values of risk parameters.
     */
    function createPerpetual(
        address oracle,
        int256[9] calldata baseParams,
        int256[8] calldata riskParams,
        int256[8] calldata minRiskParamValues,
        int256[8] calldata maxRiskParamValues
    ) external onlyNotUniverseSettled {
        if (!_liquidityPool.isRunning || _liquidityPool.isFastCreationEnabled) {
            require(
                _msgSender() == _liquidityPool.getOperator(),
                "only operator can create perpetual"
            );
        } else {
            require(_msgSender() == _liquidityPool.governor, "only governor can create perpetual");
        }
        _liquidityPool.createPerpetual(
            oracle,
            baseParams,
            riskParams,
            minRiskParamValues,
            maxRiskParamValues
        );
    }

    /**
     * @notice  Set the liquidity pool to running state. Can be call only once by operater.m n
     */
    function runLiquidityPool() external override onlyOperator {
        require(!_liquidityPool.isRunning, "already running");
        _liquidityPool.runLiquidityPool();
    }

    /**
     * @notice  If you want to get the real-time data, call this function first
     */
    function forceToSyncState() public override syncState(false) {}

    /**
     * @notice  Add liquidity to the liquidity pool.
     *          Liquidity provider deposits collaterals then gets share tokens back.
     *          The ratio of added cash to share token is determined by current liquidity.
     *          Can only called when the pool is running.
     *
     * @param   cashToAdd   The amount of cash to add. always use decimals 18.
     */
    function addLiquidity(int256 cashToAdd)
        external
        override
        onlyNotUniverseSettled
        syncState(false)
        nonReentrant
    {
        require(_liquidityPool.isRunning, "pool is not running");
        _liquidityPool.addLiquidity(_msgSender(), cashToAdd);
    }

    /**
     * @notice  Remove liquidity from the liquidity pool.
     *          Liquidity providers redeems share token then gets collateral back.
     *          The amount of collateral retrieved may differ from the amount when adding liquidity,
     *          The index price, trading fee and positions holding by amm will affect the profitability of providers.
     *          Can only called when the pool is running.
     *
     * @param   shareToRemove   The amount of share token to remove. The amount always use decimals 18.
     * @param   cashToReturn    The amount of cash(collateral) to return. The amount always use decimals 18.
     */
    function removeLiquidity(int256 shareToRemove, int256 cashToReturn)
        external
        override
        nonReentrant
        syncState(false)
    {
        require(_liquidityPool.isRunning, "pool is not running");
        if (IPoolCreatorFull(_liquidityPool.creator).isUniverseSettled()) {
            require(
                _liquidityPool.isAllPerpetualIn(PerpetualState.CLEARED),
                "all perpetual must be cleared"
            );
        }
        _liquidityPool.removeLiquidity(_msgSender(), shareToRemove, cashToReturn);
    }

    /**
     * @notice  Donate collateral to the insurance fund of the pool.
     *          Can only called when the pool is running.
     *          Donated collateral is not withdrawable but can be used to improve security.
     *          Unexpected loss (bankrupt) will be deducted from insurance fund then donated insurance fund.
     *          Until donated insurance fund is drained, the perpetual will not enter emergency state and shutdown.
     *
     * @param   amount          The amount of collateral to donate. The amount always use decimals 18.
     */
    function donateInsuranceFund(int256 amount) external nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        _liquidityPool.donateInsuranceFund(_msgSender(), amount);
    }

    /**
     * @notice  Add liquidity to the liquidity pool without getting shares.
     *
     * @param   cashToAdd   The amount of cash to add. The amount always use decimals 18.
     */
    function donateLiquidity(int256 cashToAdd) external nonReentrant {
        require(_liquidityPool.isRunning, "pool is not running");
        _liquidityPool.donateLiquidity(_msgSender(), cashToAdd);
    }

    bytes32[50] private __gap;
}
