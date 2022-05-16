// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./OracleRouter.sol";

// A factory to deploy OracleRouter. Each path should be deployed only once.
contract OracleRouterCreator {
    mapping(bytes32 => address) public routers;

    event NewOracleRouter(
        address router,
        string collateral,
        string underlyingAsset,
        OracleRouter.Route[] path
    );

    /**
     * @notice Geth hash key of given path.
     * @param path [(oracle, isInverse)]. The OracleRouterCreator never verifies whether the path is reasonable.
     *             collateral() and underlyingAsset() only shows correct value if the collateral token is in
     *             the 1st item and the underlying asset is always in the last item.
     * @return @return The encoded bytes of data
     */
    function getPathHash(OracleRouter.Route[] memory path) public pure returns (bytes32) {
        return keccak256(abi.encode(path));
    }

    /**
     * @notice Create an OracleRouter. Revert if the router is already deployed.
     * @param path [(oracle, isInverse)]. The OracleRouterCreator never verifies whether the path is reasonable.
     *             collateral() and underlyingAsset() only shows correct value if the collateral token is in
     *             the 1st item and the underlying asset is always in the last item.
     * @return instance The address of the created OracleRouter
     */
    function createOracleRouter(OracleRouter.Route[] memory path)
        public
        returns (address instance)
    {
        require(path.length > 0, "empty path");
        bytes32 key = getPathHash(path);
        require(routers[key] == address(0), "already deployed");
        OracleRouter router = new OracleRouter(path);
        instance = address(router);
        routers[key] = instance;
        emit NewOracleRouter(instance, router.collateral(), router.underlyingAsset(), path);
    }
}
