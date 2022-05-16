// SPDX-License-Identifier: GPL-3.0

/*
    This file is part of the Enzyme Protocol.

    (c) Enzyme Council <council@enzyme.finance>

    For the full license information, please view the LICENSE
    file that was distributed with this source code.
*/

pragma solidity 0.6.12;

import "../IDerivativePriceFeed.sol";

/// @title RevertingPriceFeed Contract
/// @author Enzyme Council <security@enzyme.finance>
/// @notice Price feed that always reverts on value conversion
/// @dev Used purely for extraordinary circumstances where we want to prevent value calculations,
/// while allowing an asset to continue to be in the asset universe
contract RevertingPriceFeed is IDerivativePriceFeed {
    /// @notice Converts a given amount of a derivative to its underlying asset values
    function calcUnderlyingValues(address, uint256)
        external
        override
        returns (address[] memory, uint256[] memory)
    {
        revert("calcUnderlyingValues: RevertingPriceFeed");
    }

    /// @notice Checks whether an asset is a supported primitive of the price feed
    /// @return isSupported_ True if the asset is a supported primitive
    function isSupportedAsset(address) public view override returns (bool isSupported_) {
        return true;
    }
}
