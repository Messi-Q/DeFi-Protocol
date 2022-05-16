pragma solidity ^0.5.16;

// ERC677 function
interface ITransferAndCall {
    function transferAndCall(address, uint256, bytes calldata) external returns (bool);
}