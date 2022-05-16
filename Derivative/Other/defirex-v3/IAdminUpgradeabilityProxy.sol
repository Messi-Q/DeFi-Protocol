pragma solidity ^0.5.16;

interface IAdminUpgradeabilityProxy {
    function changeAdmin(address newAdmin) external;
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}