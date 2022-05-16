// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

interface IAccessControl {
    function grantPrivilege(address trader, uint256 privilege) external;

    function revokePrivilege(address trader, uint256 privilege) external;

    function isGranted(
        address owner,
        address trader,
        uint256 privilege
    ) external view returns (bool);
}
