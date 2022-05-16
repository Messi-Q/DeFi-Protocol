// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

pragma experimental ABIEncoderV2;

import "@ozUpgradesV3/contracts/access/OwnableUpgradeable.sol";
import "@ozUpgradesV3/contracts/utils/ReentrancyGuardUpgradeable.sol";

contract UpgradeTestNew is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    uint256 public oldStorage;

    function initialize(uint256 _oldStorage) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        oldStorage = _oldStorage;
    }

    function upgrateTest() public pure returns (uint256) {
        return 2;
    }
}
