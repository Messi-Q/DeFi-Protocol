// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

interface ISymbolService {
    function isWhitelistedFactory(address factory) external view returns (bool);

    function addWhitelistedFactory(address factory) external;

    function removeWhitelistedFactory(address factory) external;

    function getPerpetualUID(uint256 symbol)
        external
        view
        returns (address liquidityPool, uint256 perpetualIndex);

    function getSymbols(address liquidityPool, uint256 perpetualIndex)
        external
        view
        returns (uint256[] memory symbols);

    function allocateSymbol(address liquidityPool, uint256 perpetualIndex) external;

    function assignReservedSymbol(
        address liquidityPool,
        uint256 perpetualIndex,
        uint256 symbol
    ) external;
}
