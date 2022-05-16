pragma solidity ^0.5.16;

interface ICEther {
    function mint() external payable;
    function repayBorrow() external payable;
}
