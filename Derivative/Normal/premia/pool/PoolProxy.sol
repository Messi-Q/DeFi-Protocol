// SPDX-License-Identifier: BUSL-1.1
// For further clarification please see https://license.premia.legal

pragma solidity ^0.8.0;

import {OwnableStorage} from "@solidstate/contracts/access/OwnableStorage.sol";
import {ERC165Storage} from "@solidstate/contracts/introspection/ERC165Storage.sol";
import {Proxy} from "@solidstate/contracts/proxy/Proxy.sol";
import {IDiamondLoupe} from "@solidstate/contracts/proxy/diamond/IDiamondLoupe.sol";
import {IERC20Metadata} from "@solidstate/contracts/token/ERC20/metadata/IERC20Metadata.sol";
import {IERC1155} from "@solidstate/contracts/token/ERC1155/IERC1155.sol";
import {IERC165} from "@solidstate/contracts/introspection/IERC165.sol";

import {IProxyManager} from "../core/IProxyManager.sol";
import {PoolStorage} from "./PoolStorage.sol";
import {ABDKMath64x64Token} from "../libraries/ABDKMath64x64Token.sol";

/**
 * @title Upgradeable proxy with centrally controlled Pool implementation
 */
contract PoolProxy is Proxy {
    using PoolStorage for PoolStorage.Layout;
    using ERC165Storage for ERC165Storage.Layout;

    address private immutable DIAMOND;

    constructor(
        address diamond,
        address base,
        address underlying,
        address baseOracle,
        address underlyingOracle,
        int128 baseMinimum64x64,
        int128 underlyingMinimum64x64,
        int128 basePoolCap64x64,
        int128 underlyingPoolCap64x64,
        int128 initialCLevel64x64,
        int128 initialSteepness64x64
    ) {
        DIAMOND = diamond;
        OwnableStorage.layout().owner = msg.sender;

        {
            PoolStorage.Layout storage l = PoolStorage.layout();

            l.base = base;
            l.underlying = underlying;

            l.setOracles(baseOracle, underlyingOracle);

            uint8 baseDecimals = IERC20Metadata(base).decimals();
            uint8 underlyingDecimals = IERC20Metadata(underlying).decimals();

            l.baseDecimals = baseDecimals;
            l.underlyingDecimals = underlyingDecimals;

            l.baseMinimum = ABDKMath64x64Token.toDecimals(
                baseMinimum64x64,
                baseDecimals
            );

            l.underlyingMinimum = ABDKMath64x64Token.toDecimals(
                underlyingMinimum64x64,
                underlyingDecimals
            );

            l.basePoolCap = ABDKMath64x64Token.toDecimals(
                basePoolCap64x64,
                baseDecimals
            );

            l.underlyingPoolCap = ABDKMath64x64Token.toDecimals(
                underlyingPoolCap64x64,
                underlyingDecimals
            );

            l.steepnessBase64x64 = initialSteepness64x64;
            l.steepnessUnderlying64x64 = initialSteepness64x64;
            l.cLevelBase64x64 = initialCLevel64x64;
            l.cLevelUnderlying64x64 = initialCLevel64x64;

            int128 newPrice64x64 = l.fetchPriceUpdate();
            l.setPriceUpdate(block.timestamp, newPrice64x64);

            l.updatedAt = block.timestamp;
            l.cLevelBaseUpdatedAt = block.timestamp;
            l.cLevelUnderlyingUpdatedAt = block.timestamp;
        }

        {
            ERC165Storage.Layout storage l = ERC165Storage.layout();
            l.setSupportedInterface(type(IERC165).interfaceId, true);
            l.setSupportedInterface(type(IERC1155).interfaceId, true);
        }
    }

    function _getImplementation() internal view override returns (address) {
        return IDiamondLoupe(DIAMOND).facetAddress(msg.sig);
    }
}
