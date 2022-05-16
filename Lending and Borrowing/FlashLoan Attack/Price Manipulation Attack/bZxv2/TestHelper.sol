// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "./CustomERC20.sol";

contract TestHelper {
    function createERC20(
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 nonce
    ) external returns (address instance) {
        bytes32 salt = keccak256(abi.encodePacked(name, symbol, decimals, nonce));
        bytes memory deploymentData = abi.encodePacked(
            type(CustomERC20).creationCode,
            abi.encode(name, symbol, decimals)
        );
        assembly {
            instance := create2(0x0, add(0x20, deploymentData), mload(deploymentData), salt)
        }
        require(instance != address(0), "Create2 call failed");
    }
}
