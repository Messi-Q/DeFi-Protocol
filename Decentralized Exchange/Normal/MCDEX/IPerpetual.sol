// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

import "../Type.sol";

interface IPerpetual {
    /**
     * @notice  Deposit collateral to the perpetual.
     *          Can only called when the perpetual's state is "NORMAL".
     *          This method will always increase `cash` amount in trader's margin account.
     *
     * @param   perpetualIndex  The index of the perpetual in the liquidity pool.
     * @param   trader          The address of the trader.
     * @param   amount          The amount of collateral to deposit. The amount always use decimals 18.
     */
    function deposit(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) external;

    /**
     * @notice  Withdraw collateral from the trader's account of the perpetual.
     *          After withdrawn, trader shall at least has maintenance margin left in account.
     *          Can only called when the perpetual's state is "NORMAL".
     *          Margin account must at least keep
     *          The trader's cash will decrease in the perpetual.
     *          Need to update the funding state and the oracle price of each perpetual before
     *          and update the funding rate of each perpetual after
     *
     * @param   perpetualIndex  The index of the perpetual in the liquidity pool.
     * @param   trader          The address of the trader.
     * @param   amount          The amount of collateral to withdraw. The amount always use decimals 18.
     */
    function withdraw(
        uint256 perpetualIndex,
        address trader,
        int256 amount
    ) external;

    /**
     * @notice  If the state of the perpetual is "CLEARED", anyone authorized withdraw privilege by trader can settle
     *          trader's account in the perpetual. Which means to calculate how much the collateral should be returned
     *          to the trader, return it to trader's wallet and clear the trader's cash and position in the perpetual.
     *
     * @param   perpetualIndex  The index of the perpetual in the liquidity pool
     * @param   trader          The address of the trader.
     */
    function settle(uint256 perpetualIndex, address trader) external;

    /**
     * @notice  Clear the next active account of the perpetual which state is "EMERGENCY" and send gas reward of collateral
     *          to sender. If all active accounts are cleared, the clear progress is done and the perpetual's state will
     *          change to "CLEARED". Active means the trader's account is not empty in the perpetual.
     *          Empty means cash and position are zero
     *
     * @param   perpetualIndex  The index of the perpetual in the liquidity pool.
     */
    function clear(uint256 perpetualIndex) external;

    /**
     * @notice Trade with AMM in the perpetual, require sender is granted the trade privilege by the trader.
     *         The trading price is determined by the AMM based on the index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param trader The address of trader
     * @param amount The position amount of the trade
     * @param limitPrice The worst price the trader accepts
     * @param deadline The deadline of the trade
     * @param referrer The referrer's address of the trade
     * @param flags The flags of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function trade(
        uint256 perpetualIndex,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline,
        address referrer,
        uint32 flags
    ) external returns (int256);

    /**
     * @notice Trade with AMM by the order, initiated by the broker.
     *         The trading price is determined by the AMM based on the index price of the perpetual.
     *         Trader must be initial margin safe if opening position and margin safe if closing position
     * @param orderData The order data object
     * @param amount The position amount of the trade
     * @return int256 The update position amount of the trader after the trade
     */
    function brokerTrade(bytes memory orderData, int256 amount) external returns (int256);

    /**
     * @notice  Liquidate the trader if the trader's margin balance is lower than maintenance margin (unsafe).
     *          Liquidate can be considered as a forced trading between AMM and unsafe margin account;
     *          Based on current liquidity of AMM, it may take positions up to an amount equal to all the position
     *          of the unsafe account. Besides the position, trader need to pay an extra penalty to AMM
     *          for taking the unsafe assets. See TradeModule.sol for ehe strategy of penalty.
     *
     *          The liquidate price will be determined by AMM.
     *          Caller of this method can be anyone, then get a reward to make up for transaction gas fee.
     *
     *          If a trader's margin balance is lower than 0 (bankrupt), insurance fund will be use to fill the loss
     *          to make the total profit and loss balanced. (first the `insuranceFund` then the `donatedInsuranceFund`)
     *
     *          If insurance funds are drained, the state of perpetual will turn to enter "EMERGENCY" than shutdown.
     *          Can only liquidate when the perpetual's state is "NORMAL".
     *
     * @param   perpetualIndex      The index of the perpetual in liquidity pool
     * @param   trader              The address of trader to be liquidated.
     * @return  liquidationAmount   The amount of positions actually liquidated in the transaction. The amount always use decimals 18.
     */
    function liquidateByAMM(uint256 perpetualIndex, address trader)
        external
        returns (int256 liquidationAmount);

    /**
     * @notice  This method is generally consistent with `liquidateByAMM` function, but there some difference:
     *           - The liquidation price is no longer determined by AMM, but the mark price;
     *           - The penalty is taken by trader who takes position but AMM;
     *
     * @param   perpetualIndex      The index of the perpetual in liquidity pool.
     * @param   liquidator          The address of liquidator to receive the liquidated position.
     * @param   trader              The address of trader to be liquidated.
     * @param   amount              The amount of position to be taken from liquidated trader. The amount always use decimals 18.
     * @param   limitPrice          The worst price liquidator accepts.
     * @param   deadline            The deadline of transaction.
     * @return  liquidationAmount   The amount of positions actually liquidated in the transaction.
     */
    function liquidateByTrader(
        uint256 perpetualIndex,
        address liquidator,
        address trader,
        int256 amount,
        int256 limitPrice,
        uint256 deadline
    ) external returns (int256 liquidationAmount);
}
