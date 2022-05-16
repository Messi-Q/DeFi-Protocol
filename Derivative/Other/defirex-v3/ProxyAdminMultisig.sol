pragma solidity ^0.5.16;

import "./MultiOwnable.sol";

// **INTERFACES**
import "./interfaces/IAdminUpgradeabilityProxy.sol";


/**
 * @title ProxyAdminMultisig
 * @dev This contract is the admin of a proxy, and is in charge
 * of upgrading it as well as transferring it to another admin.
 */
contract ProxyAdminMultisig is MultiOwnable {

    constructor() public {
        address[] memory newOwners = new address[](1);
        newOwners[0] = 0xdAE0aca4B9B38199408ffaB32562Bf7B3B0495fE;
        initialize(newOwners);
    }


    /**
     * @dev Returns the current implementation of a proxy.
     * This is needed because only the proxy admin can query it.
     * @return The address of the current implementation of the proxy.
     */
    function getProxyImplementation(IAdminUpgradeabilityProxy proxy) public view returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("implementation()")) == 0x5c60da1b
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"5c60da1b");
        require(success);
        return abi.decode(returndata, (address));
    }

    /**
     * @dev Returns the admin of a proxy. Only the admin can query it.
     * @return The address of the current admin of the proxy.
     */
    function getProxyAdmin(IAdminUpgradeabilityProxy proxy) public view returns (address) {
        // We need to manually run the static call since the getter cannot be flagged as view
        // bytes4(keccak256("admin()")) == 0xf851a440
        (bool success, bytes memory returndata) = address(proxy).staticcall(hex"f851a440");
        require(success);
        return abi.decode(returndata, (address));
    }

    /**
     * @dev Changes the admin of a proxy.
     * @param proxy Proxy to change admin.
     * @param newAdmin Address to transfer proxy administration to.
     */
    function changeProxyAdmin(IAdminUpgradeabilityProxy proxy, address newAdmin) public onlyMultiOwners {
        proxy.changeAdmin(newAdmin);
    }

    /**
     * @dev Upgrades a proxy to the newest implementation of a contract.
     * @param proxy Proxy to be upgraded.
     * @param implementation the address of the Implementation.
     */
    function upgrade(IAdminUpgradeabilityProxy proxy, address implementation) public onlyMultiOwners {
        proxy.upgradeTo(implementation);
    }

    /**
     * @dev Upgrades a proxy to the newest implementation of a contract and forwards a function call to it.
     * This is useful to initialize the proxied contract.
     * @param proxy Proxy to be upgraded.
     * @param implementation Address of the Implementation.
     * @param data Data to send as msg.data in the low level call.
     * It should include the signature and the parameters of the function to be called, as described in
     * https://solidity.readthedocs.io/en/v0.4.24/abi-spec.html#function-selector-and-argument-encoding.
     */
    function upgradeAndCall(IAdminUpgradeabilityProxy proxy, address implementation, bytes memory data) public payable  onlyMultiOwners {
        proxy.upgradeToAndCall.value(msg.value)(implementation, data);
    }
}