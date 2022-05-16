// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

import {ABDKMath64x64} from "abdk-libraries-solidity/ABDKMath64x64.sol";
import {IERC20} from "@solidstate/contracts/token/ERC20/IERC20.sol";
import {ERC1155BaseStorage} from "@solidstate/contracts/token/ERC1155/base/ERC1155BaseStorage.sol";
import {SafeERC20} from "@solidstate/contracts/utils/SafeERC20.sol";
import {EnumerableSet} from "@solidstate/contracts/utils/EnumerableSet.sol";

import {ABDKMath64x64Token} from "../libraries/ABDKMath64x64Token.sol";
import {PoolSwap} from "./PoolSwap.sol";
import {PoolStorage} from "./PoolStorage.sol";
import {IPoolWrite} from "./IPoolWrite.sol";

/**
 * @title Premia option pool
 * @dev deployed standalone and referenced by PoolProxy
 */
contract PoolWrite is IPoolWrite, PoolSwap {
    using SafeERC20 for IERC20;
    using ABDKMath64x64 for int128;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using PoolStorage for PoolStorage.Layout;

    constructor(
        address ivolOracle,
        address weth,
        address premiaMining,
        address feeReceiver,
        address feeDiscountAddress,
        int128 fee64x64,
        address uniswapV2Factory,
        address sushiswapFactory
    )
        PoolSwap(
            ivolOracle,
            weth,
            premiaMining,
            feeReceiver,
            feeDiscountAddress,
            fee64x64,
            uniswapV2Factory,
            sushiswapFactory
        )
    {}

    /**
     * @inheritdoc IPoolWrite
     */
    function quote(
        address feePayer,
        uint64 maturity,
        int128 strike64x64,
        uint256 contractSize,
        bool isCall
    )
        external
        view
        override
        returns (
            int128 baseCost64x64,
            int128 feeCost64x64,
            int128 cLevel64x64,
            int128 slippageCoefficient64x64
        )
    {
        int128 spot64x64;

        PoolStorage.Layout storage l = PoolStorage.layout();
        if (l.updatedAt != block.timestamp) {
            spot64x64 = l.fetchPriceUpdate();
        } else {
            spot64x64 = l.getPriceUpdate(block.timestamp);
        }

        PoolStorage.QuoteResultInternal memory quoteResult = _quote(
            PoolStorage.QuoteArgsInternal(
                feePayer,
                maturity,
                strike64x64,
                spot64x64,
                contractSize,
                isCall
            )
        );

        return (
            quoteResult.baseCost64x64,
            quoteResult.feeCost64x64,
            quoteResult.cLevel64x64,
            quoteResult.slippageCoefficient64x64
        );
    }

    /**
     * @inheritdoc IPoolWrite
     */
    function purchase(
        uint64 maturity,
        int128 strike64x64,
        uint256 contractSize,
        bool isCall,
        uint256 maxCost
    ) external payable override returns (uint256 baseCost, uint256 feeCost) {
        return
            _verifyAndPurchase(
                maturity,
                strike64x64,
                contractSize,
                isCall,
                maxCost,
                false
            );
    }

    /**
     * @inheritdoc IPoolWrite
     */
    function swapAndPurchase(
        uint64 maturity,
        int128 strike64x64,
        uint256 contractSize,
        bool isCall,
        uint256 maxCost,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        bool isSushi
    ) public payable override returns (uint256 baseCost, uint256 feeCost) {
        // If value is passed, amountInMax must be 0, as the value wont be used
        // If amountInMax is not 0, user wants to do a swap from an ERC20, and therefore no value should be attached
        require(
            msg.value == 0 || amountInMax == 0,
            "value and amountInMax passed"
        );

        // If no amountOut has been passed, we swap the exact amount required to pay the quote
        if (amountOut == 0) {
            PoolStorage.Layout storage l = PoolStorage.layout();

            int128 newPrice64x64 = _update(l);

            PoolStorage.QuoteArgsInternal memory quoteArgs;
            quoteArgs.feePayer = msg.sender;
            quoteArgs.maturity = maturity;
            quoteArgs.strike64x64 = strike64x64;
            quoteArgs.spot64x64 = newPrice64x64;
            quoteArgs.contractSize = contractSize;
            quoteArgs.isCall = isCall;

            PoolStorage.QuoteResultInternal memory purchaseQuote = _quote(
                quoteArgs
            );

            amountOut = ABDKMath64x64Token.toDecimals(
                purchaseQuote.baseCost64x64.add(purchaseQuote.feeCost64x64),
                l.getTokenDecimals(isCall)
            );
        }

        if (msg.value > 0) {
            _swapETHForExactTokens(amountOut, path, isSushi);
        } else {
            _swapTokensForExactTokens(amountOut, amountInMax, path, isSushi);
        }

        return
            _verifyAndPurchase(
                maturity,
                strike64x64,
                contractSize,
                isCall,
                maxCost,
                true
            );
    }

    /**
     * @inheritdoc IPoolWrite
     */
    function writeFrom(
        address underwriter,
        address longReceiver,
        uint64 maturity,
        int128 strike64x64,
        uint256 contractSize,
        bool isCall
    )
        external
        payable
        override
        returns (uint256 longTokenId, uint256 shortTokenId)
    {
        require(
            msg.sender == underwriter ||
                ERC1155BaseStorage.layout().operatorApprovals[underwriter][
                    msg.sender
                ],
            "not approved"
        );

        address token = _getPoolToken(isCall);

        uint256 tokenAmount = isCall
            ? contractSize
            : PoolStorage.layout().fromUnderlyingToBaseDecimals(
                strike64x64.mulu(contractSize)
            );

        _pullFrom(underwriter, token, tokenAmount, false);

        longTokenId = PoolStorage.formatTokenId(
            _getTokenType(isCall, true),
            maturity,
            strike64x64
        );
        shortTokenId = PoolStorage.formatTokenId(
            _getTokenType(isCall, false),
            maturity,
            strike64x64
        );

        // mint long option token for designated receiver
        _mint(longReceiver, longTokenId, contractSize);
        // mint short option token for underwriter
        _mint(underwriter, shortTokenId, contractSize);

        emit Underwrite(
            underwriter,
            longReceiver,
            shortTokenId,
            contractSize,
            0,
            true
        );
    }

    /**
     * @inheritdoc IPoolWrite
     */
    function update() external override {
        _update(PoolStorage.layout());
    }

    /**
     * @notice verify parameters, purchase option, and transfer payment into contract
     * @param maturity timestamp of option maturity
     * @param strike64x64 64x64 fixed point representation of strike price
     * @param contractSize size of option contract
     * @param isCall true for call, false for put
     * @param maxCost maximum acceptable cost after accounting for slippage
     * @param skipWethDeposit if false, will not try to deposit weth from attach eth
     * @return baseCost quantity of tokens required to purchase long position
     * @return feeCost quantity of tokens required to pay fees
     */
    function _verifyAndPurchase(
        uint64 maturity,
        int128 strike64x64,
        uint256 contractSize,
        bool isCall,
        uint256 maxCost,
        bool skipWethDeposit
    ) internal returns (uint256 baseCost, uint256 feeCost) {
        PoolStorage.Layout storage l = PoolStorage.layout();

        require(maturity >= block.timestamp + (1 days), "exp < 1 day");
        require(maturity < block.timestamp + (91 days), "exp > 90 days");
        require(maturity % (8 hours) == 0, "exp must be 8-hour increment");

        int128 newPrice64x64 = _update(l);

        if (isCall) {
            require(
                strike64x64 <= newPrice64x64 << 1 &&
                    strike64x64 >= (newPrice64x64 * 8) / 10,
                "strike out of range"
            );
        } else {
            require(
                strike64x64 <= (newPrice64x64 * 12) / 10 &&
                    strike64x64 >= newPrice64x64 >> 1,
                "strike out of range"
            );
        }

        (baseCost, feeCost) = _purchase(
            l,
            msg.sender,
            maturity,
            strike64x64,
            isCall,
            contractSize,
            newPrice64x64
        );

        require(baseCost + feeCost <= maxCost, "excess slipp");

        _pullFrom(
            msg.sender,
            _getPoolToken(isCall),
            baseCost + feeCost,
            skipWethDeposit
        );
    }
}
