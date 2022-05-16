// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockPoolCreator is Ownable {
    constructor(address owner_) Ownable() {
        transferOwnership(owner_);
    }
}
