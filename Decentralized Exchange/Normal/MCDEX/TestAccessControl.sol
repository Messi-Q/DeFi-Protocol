// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "../libraries/Constant.sol";
import "../factory/AccessControl.sol";

contract TestAccessControl is AccessControl {
    using EnumerableMapExt for EnumerableMapExt.AddressToUintMap;

    function privileges(address account, address trader) public view returns (uint256) {
        return _accessControls[account].get(trader);
    }

    modifier auth(address trader, uint256 privilege) {
        require(
            msg.sender == trader || isGranted(trader, msg.sender, privilege),
            "operation forbidden"
        );
        _;
    }

    function deposit(address trader) public auth(trader, Constant.PRIVILEGE_DEPOSIT) {}

    function withdraw(address trader) public auth(trader, Constant.PRIVILEGE_WITHDRAW) {}

    function trade(address trader) public auth(trader, Constant.PRIVILEGE_TRADE) {}
}
