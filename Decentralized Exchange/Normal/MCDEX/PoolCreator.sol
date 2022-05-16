// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "./KeeperWhitelist.sol";
import "./PoolCreatorV2.sol";

contract PoolCreator is PoolCreatorV2 {
    bool public override isUniverseSettled;
    uint256 public poolVersion;
    uint256 public guardianCount;
    mapping(address => bool) public guardians;

    event AddGuardian(address indexed account);
    event TransferGuardian(address indexed fromAccount, address indexed toAccount);
    event RenounceGuardian(address indexed account);
    event SetUniverseSettled();

    modifier onlyGuardian() {
        require(isGuardian(_msgSender()), "sender is not guardian");
        _;
    }

    function isGuardian(address account) public view returns (bool) {
        return guardians[account];
    }

    /**
     * @notice  Set the guardian who is able to set `isUniverseSettled` flag.
     */
    function addGuardian(address account) public onlyOwner {
        _addGuardian(account);
    }

    /**
     * @notice  Transfer guardian from sender to some account.
     */
    function transferGuardian(address toAccount) public onlyGuardian {
        require(toAccount != address(0), "guardian is zero address");
        require(!isGuardian(toAccount), "guardian is already set");
        address fromAccount = _msgSender();
        guardians[fromAccount] = false;
        guardians[toAccount] = true;
        emit TransferGuardian(fromAccount, toAccount);
    }

    /**
     * @notice  Renounce guardian.
     */
    function renounceGuardian() external onlyGuardian {
        address account = _msgSender();
        guardians[account] = false;
        guardianCount--;
        emit RenounceGuardian(account);
    }

    /**
     * @notice  Indicates the universe settle state. When called:
     *          - all the perpetual created by this poolCreator can be settled immediately;
     *          - all the trading method will be unavailable.
     */
    function setUniverseSettled() external onlyGuardian {
        require(!isUniverseSettled, "state is not changed");
        isUniverseSettled = true;
        emit SetUniverseSettled();
    }

    function _addGuardian(address account) internal {
        require(account != address(0), "guardian is zero address");
        require(!isGuardian(account), "guardian is already set");
        guardians[account] = true;
        guardianCount++;
        emit AddGuardian(account);
    }
}
