// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./UniswapV3OracleAdaptor.sol";

// A factory to deploy UniswapV3OracleAdaptor. The same adaptor should be deployed only once.
contract UniswapV3OracleAdaptorCreator {
    struct AdaptorData {
        address[] path;
        uint24[] fees;
        uint32 shortPeriod;
        uint32 longPeriod;
    }

    mapping(bytes32 => address) public adaptors;

    event NewUniswapV3OracleAdaptor(
        address adaptor,
        address[] path,
        uint24[] fees,
        uint32 shortPeriod,
        uint32 longPeriod
    );

    /**
     * @notice Geth hash key of given data.
     * @return The encoded bytes of data
     */
    function getAdaptorDataHash(AdaptorData memory adaptorData) public pure returns (bytes32) {
        return keccak256(abi.encode(adaptorData));
    }

    /**
     * @notice Create an adaptor. Revert if the adaptor is already deployed.
     * @return instance The address of the created adaptor
     */
    function createAdaptor(
        address factory,
        address[] memory path,
        uint24[] memory fees,
        uint32 shortPeriod,
        uint32 longPeriod
    ) public returns (address instance) {
        AdaptorData memory adaptorData = AdaptorData(path, fees, shortPeriod, longPeriod);
        bytes32 key = getAdaptorDataHash(adaptorData);
        require(adaptors[key] == address(0), "already deployed");
        UniswapV3OracleAdaptor adaptor = new UniswapV3OracleAdaptor(
            factory,
            path,
            fees,
            shortPeriod,
            longPeriod
        );
        instance = address(adaptor);
        adaptors[key] = instance;
        emit NewUniswapV3OracleAdaptor(instance, path, fees, shortPeriod, longPeriod);
    }
}
