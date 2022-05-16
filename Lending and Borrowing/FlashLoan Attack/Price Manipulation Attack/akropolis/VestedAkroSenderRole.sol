// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

import "@ozUpgradesV3/contracts/GSN/ContextUpgradeable.sol";
import "@ozUpgradesV3/contracts/proxy/Initializable.sol";
import "./Roles.sol";

contract VestedAkroSenderRole is Initializable, ContextUpgradeable {
    using Roles for Roles.Role;

    event SenderAdded(address indexed account);
    event SenderRemoved(address indexed account);

    Roles.Role private _senders;

    function initialize(address sender) public virtual initializer {
        __Context_init_unchained();
        if (!isSender(sender)) {
            _addSender(sender);
        }
    }

    modifier onlySender() {
        require(isSender(_msgSender()), "SenderRole: caller does not have the Sender role");
        _;
    }

    function isSender(address account) public view returns (bool) {
        return _senders.has(account);
    }

    function addSender(address account) public onlySender {
        _addSender(account);
    }

    function renounceSender() public {
        _removeSender(_msgSender());
    }

    function _addSender(address account) internal {
        _senders.add(account);
        emit SenderAdded(account);
    }

    function _removeSender(address account) internal {
        _senders.remove(account);
        emit SenderRemoved(account);
    }

    uint256[50] private ______gap;
}
