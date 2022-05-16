// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";

contract InverseStateService {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    EnumerableSet.Bytes32Set internal _inverseStates;

    event SetInverseState(address indexed liquidityPool, uint256 perpetualIndex, bool isInverse);

    function setInverseState(
        address liquidityPool,
        uint256 perpetualIndex,
        bool isInverse_
    ) external {
        require(liquidityPool != address(0), "liquidityPool is zero address");
        (address operator, uint256 perpetualCount) = _getLiquidityPoolInfo(liquidityPool);
        require(msg.sender == operator, "caller must be the operator of the liquidityPool");
        require(perpetualIndex < perpetualCount, "perpetualIndex exceeds count of perpetuals");

        bytes32 key = _encode(liquidityPool, perpetualIndex);
        bool isExist = _inverseStates.contains(key);
        require(isInverse_ ? !isExist : isExist, "duplicated operation");
        if (isInverse_) {
            _inverseStates.add(key);
        } else {
            _inverseStates.remove(key);
        }
        emit SetInverseState(liquidityPool, perpetualIndex, isInverse_);
    }

    function isInverse(address liquidityPool, uint256 perpetualIndex) public view returns (bool) {
        return _inverseStates.contains(_encode(liquidityPool, perpetualIndex));
    }

    function export(uint256 begin, uint256 end) external view returns (bytes32[] memory result) {
        require(end > begin, "begin should be lower than end");
        uint256 length = _inverseStates.length();
        if (begin >= length) {
            return result;
        }
        uint256 safeEnd = end > length ? length : end;
        result = new bytes32[](safeEnd - begin);
        for (uint256 i = begin; i < safeEnd; i++) {
            result[i - begin] = _inverseStates.at(i);
        }
        return result;
    }

    function _getLiquidityPoolInfo(address liquidityPool)
        internal
        view
        returns (address operator, uint256 perpetualCount)
    {
        (bool success, bytes memory result) = liquidityPool.staticcall(
            abi.encodeWithSignature("getLiquidityPoolInfo()")
        );
        require(success, "call getLiquidityPoolInfo failed");
        assembly {
            operator := mload(add(result, 128)) // 32 + 32 * 3
            perpetualCount := mload(add(result, 512)) // 32 + 32 * 15
        }
    }

    function _encode(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32 key)
    {
        require(perpetualIndex <= type(uint32).max, "perpetualIndex exceeds uint32.max");
        bytes memory packed = abi.encodePacked(liquidityPool, uint32(perpetualIndex));
        assembly {
            key := mload(add(packed, 32))
        }
    }

    function _decode(bytes32 key)
        internal
        pure
        returns (address liquidityPool, uint256 perpetualIndex)
    {
        liquidityPool = address(bytes20(key));
        perpetualIndex = uint256(uint32(bytes4(key << 160)));
    }
}
