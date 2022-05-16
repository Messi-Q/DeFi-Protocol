// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

import {ERC1155BaseStorage} from "@solidstate/contracts/token/ERC1155/base/ERC1155BaseStorage.sol";

import {PoolInternal} from "./PoolInternal.sol";
import {IPoolExercise} from "./IPoolExercise.sol";

/**
 * @title Premia option pool
 * @dev deployed standalone and referenced by PoolProxy
 */
contract PoolExercise is IPoolExercise, PoolInternal {
    constructor(
        address ivolOracle,
        address weth,
        address premiaMining,
        address feeReceiver,
        address feeDiscountAddress,
        int128 fee64x64
    )
        PoolInternal(
            ivolOracle,
            weth,
            premiaMining,
            feeReceiver,
            feeDiscountAddress,
            fee64x64
        )
    {}

    /**
     * @inheritdoc IPoolExercise
     */
    function exerciseFrom(
        address holder,
        uint256 longTokenId,
        uint256 contractSize
    ) external override {
        if (msg.sender != holder) {
            require(
                ERC1155BaseStorage.layout().operatorApprovals[holder][
                    msg.sender
                ],
                "not approved"
            );
        }

        _exercise(holder, longTokenId, contractSize);
    }

    /**
     * @inheritdoc IPoolExercise
     */
    function processExpired(uint256 longTokenId, uint256 contractSize)
        external
        override
    {
        _exercise(address(0), longTokenId, contractSize);
    }
}
