// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";

import "../Type.sol";

library Signature {
    uint8 internal constant SIGN_TYPE_ETH = 0x0;
    uint8 internal constant SIGN_TYPE_EIP712 = 0x1;

    /*
     * @dev Get the signer of the transaction
     * @param signedHash The hash of the transaction
     * @param signature The signature of the transaction
     * @return signer The signer of the transaction
     */
    function getSigner(bytes32 digest, bytes memory signature)
        internal
        pure
        returns (address signer)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        uint8 signType;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
            signType := byte(1, mload(add(signature, 0x60)))
        }
        if (signType == SIGN_TYPE_ETH) {
            digest = ECDSAUpgradeable.toEthSignedMessageHash(digest);
        } else if (signType != SIGN_TYPE_EIP712) {
            revert("unsupported sign type");
        }
        signer = ECDSAUpgradeable.recover(digest, v, r, s);
    }
}
