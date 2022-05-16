// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/cryptography/ECDSAUpgradeable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../libraries/OrderData.sol";
import "../libraries/Signature.sol";

contract TestCalc is Ownable {
    using Address for address;

    uint256 public count;

    mapping(uint256 => mapping(address => int256)) internal _balances;

    // new domain, with version and chainId
    string internal constant DOMAIN_NAME_V3 = "Mai L2 Call";
    string internal constant DOMAIN_VERSION_V3 = "v3.0";
    bytes32 internal constant EIP712_DOMAIN_TYPEHASH_V3 =
        keccak256(abi.encodePacked("EIP712Domain(string name,string version,uint256 chainID)"));

    bytes32 internal constant CALL_FUNCTION_TYPE =
        keccak256(
            "Call(string method,address broker,address from,address to,bytes callData,uint32 nonce,uint32 expiration,uint64 gasLimit)"
            // "Call(address from)"
        );

    function getDomainSeperator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    EIP712_DOMAIN_TYPEHASH_V3,
                    keccak256(bytes(DOMAIN_NAME_V3)),
                    keccak256(bytes(DOMAIN_VERSION_V3)),
                    Utils.chainID()
                )
            );
    }

    function add(uint256 value) public {
        require(count + value > count, "overflow");
        count = count + value;
    }

    function sub(uint256 value) public {
        require(value <= count, "underflow");
        count = count - value;
    }

    function balanceOf(uint256 perpetualIndex, address account) public view returns (int256) {
        return _balances[perpetualIndex][account];
    }

    function deposit(
        uint256 perpetualIndex,
        address account,
        int256 amount
    ) external {
        _balances[perpetualIndex][account] = _balances[perpetualIndex][account] + amount;
    }

    bytes32 internal constant EIP712_ORDER_TYPE =
        keccak256(abi.encodePacked("Order(address trader)"));

    function callFunction(
        address from,
        string memory method,
        bytes memory callData,
        uint32 nonce,
        uint32 expiration,
        uint64 gasFeeLimit,
        bytes memory signature
    ) public {
        require(expiration >= block.timestamp, "expired 1111");
        bytes32 result = keccak256(
            abi.encode(
                EIP712_ORDER_TYPE,
                // keccak256(bytes(method)),
                address(0x6766F3CFD606E1E428747D3364baE65B6f914D56)
                // from
                // address(this),
                // keccak256(callData),
                // nonce,
                // expiration,
                // gasFeeLimit
            )
        );
        bytes32 signedHash = keccak256(
            abi.encodePacked("\x19\x01", OrderData.DOMAIN_SEPARATOR, result)
        );
        address signer = _getEIP712Signer(signedHash, signature);
        require(signer == from, "signer not match 1111");
        (bool success, ) = address(this).delegatecall(
            abi.encodePacked(bytes4(keccak256(bytes(method))), callData)
        );
        require(success, "call failed");
    }

    function _getEIP712Signer(bytes32 signedHash, bytes memory signature)
        internal
        view
        returns (address signer)
    {
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }
        require(
            uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
            "ECDSA: invalid signature 's' value"
        );
        require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");
        signer = ecrecover(signedHash, v, r, s);
        require(signer != address(0), "invalid signature");
    }

    function _decodeUserData1(bytes32 userData)
        internal
        view
        returns (
            address account,
            uint32 nonce,
            uint32 expiration,
            uint32 gasFeeLimit
        )
    {
        account = address(bytes20(userData));
        nonce = uint32(bytes4(userData << 160));
        expiration = uint32(bytes4(userData << 192));
        gasFeeLimit = uint32(bytes4(userData << 224));
    }

    function _decodeUserData2(bytes32 userData) internal view returns (address to, uint32 gasFee) {
        to = address(bytes20(userData));
        gasFee = uint32(bytes4(userData << 160));
    }
}
