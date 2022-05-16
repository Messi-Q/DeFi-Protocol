// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SignedSafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/SafeCastUpgradeable.sol";

import "../interface/IDecimals.sol";

import "../libraries/Constant.sol";

import "../Type.sol";

/**
 * @title   Collateral Module
 * @dev     Handle underlying collaterals.
 *          In this file, parameter named with:
 *              - [amount] means internal amount
 *              - [rawAmount] means amount in decimals of underlying collateral
 */
library CollateralModule {
    using SafeMathUpgradeable for uint256;
    using SafeCastUpgradeable for int256;
    using SafeCastUpgradeable for uint256;
    using SignedSafeMathUpgradeable for int256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 internal constant SYSTEM_DECIMALS = 18;

    /**
     * @notice  Initialize the collateral of the liquidity pool. Set up address, scaler and decimals of collateral
     * @param   liquidityPool       The liquidity pool object
     * @param   collateral          The address of the collateral
     * @param   collateralDecimals  The decimals of the collateral, must less than SYSTEM_DECIMALS,
     *                              must equal to decimals() if the function exists
     */
    function initializeCollateral(
        LiquidityPoolStorage storage liquidityPool,
        address collateral,
        uint256 collateralDecimals
    ) public {
        require(collateralDecimals <= SYSTEM_DECIMALS, "collateral decimals is out of range");
        try IDecimals(collateral).decimals() returns (uint8 decimals) {
            require(decimals == collateralDecimals, "decimals not match");
        } catch {}
        uint256 factor = 10**(SYSTEM_DECIMALS.sub(collateralDecimals));
        liquidityPool.scaler = (factor == 0 ? 1 : factor);
        liquidityPool.collateralToken = collateral;
        liquidityPool.collateralDecimals = collateralDecimals;
    }

    /**
     * @notice  Transfer collateral from the account to the liquidity pool.
     * @param   liquidityPool   The liquidity pool object
     * @param   account         The address of the account
     * @param   amount          The amount of erc20 token to transfer. Always use decimals 18.
     */
    function transferFromUser(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        if (amount <= 0) {
            return;
        }
        uint256 rawAmount = _toRawAmountRoundUp(liquidityPool, amount);
        IERC20Upgradeable collateralToken = IERC20Upgradeable(liquidityPool.collateralToken);
        uint256 previousBalance = collateralToken.balanceOf(address(this));
        collateralToken.safeTransferFrom(account, address(this), rawAmount);
        uint256 postBalance = collateralToken.balanceOf(address(this));
        require(postBalance.sub(previousBalance) == rawAmount, "incorrect transferred in amount");
    }

    /**
     * @notice  Transfer collateral from the liquidity pool to the account.
     * @param   liquidityPool   The liquidity pool object
     * @param   account         The address of the account
     * @param   amount          The amount of collateral to transfer. always use decimals 18.
     */
    function transferToUser(
        LiquidityPoolStorage storage liquidityPool,
        address account,
        int256 amount
    ) public {
        if (amount <= 0) {
            return;
        }
        uint256 rawAmount = _toRawAmount(liquidityPool, amount);
        IERC20Upgradeable collateralToken = IERC20Upgradeable(liquidityPool.collateralToken);
        uint256 previousBalance = collateralToken.balanceOf(address(this));
        collateralToken.safeTransfer(account, rawAmount);
        uint256 postBalance = collateralToken.balanceOf(address(this));
        require(previousBalance.sub(postBalance) == rawAmount, "incorrect transferred out amount");
    }

    function _toRawAmount(LiquidityPoolStorage storage liquidityPool, int256 amount)
        private
        view
        returns (uint256 rawAmount)
    {
        rawAmount = amount.toUint256().div(liquidityPool.scaler);
    }

    function _toRawAmountRoundUp(LiquidityPoolStorage storage liquidityPool, int256 amount)
        private
        view
        returns (uint256 rawAmount)
    {
        rawAmount = amount.toUint256();
        rawAmount = rawAmount.div(liquidityPool.scaler).add(
            rawAmount % liquidityPool.scaler > 0 ? 1 : 0
        );
    }
}
