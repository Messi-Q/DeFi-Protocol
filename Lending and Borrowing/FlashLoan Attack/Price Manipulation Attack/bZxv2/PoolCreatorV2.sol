// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./KeeperWhitelist.sol";
import "./PoolCreatorV1.sol";

abstract contract PoolCreatorV2 is PoolCreatorV1, KeeperWhitelist {
    /**
     * @notice Owner of version control.
     */
    function owner() public view override(OwnableUpgradeable, PoolCreatorV1) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
