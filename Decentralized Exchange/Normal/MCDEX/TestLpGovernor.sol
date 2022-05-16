// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../governance/LpGovernor.sol";

contract TestLpGovernor is LpGovernor {
    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure virtual override returns (uint256) {
        return 20;
    }

    function executionDelay() public pure virtual override returns (uint256) {
        return 20;
    }

    function unlockDelay() public pure virtual override returns (uint256) {
        return 20;
    }

    function setCreator(address creator_) public {
        _creator = IPoolCreatorFull(creator_);
    }

    function setTarget(address creator_) public {
        _creator = IPoolCreatorFull(creator_);
    }

    function _getTransferDelay() internal view virtual override returns (uint256) {
        if (_target == address(0)) return 0;
        return super._getTransferDelay();
    }
}
