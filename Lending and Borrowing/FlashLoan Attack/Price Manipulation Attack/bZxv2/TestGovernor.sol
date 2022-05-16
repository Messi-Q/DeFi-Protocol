// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IUpgradeableProxy {
    function implementation() external view returns (address implementation_);

    function upgradeTo(address newImplementation) external;
}

contract TestGovernor {
    using Address for address;

    fallback() external payable {}

    function getImplementation(address liquidityPool)
        external
        view
        returns (address implementation)
    {
        implementation = IUpgradeableProxy(liquidityPool).implementation();
    }

    function upgradeTo(address liquidityPool, address newImplementation) external {
        IUpgradeableProxy(liquidityPool).upgradeTo(newImplementation);
    }

    function functionCall(
        address liquidityPool,
        bytes calldata data,
        uint256 value
    ) external payable returns (bytes memory result) {
        result = liquidityPool.functionCallWithValue(data, value);
    }
}
