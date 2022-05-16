pragma solidity ^0.6.0;

abstract contract IBasicTokenAdapters {
    bytes32 public collateralType;

    function decimals() virtual public view returns (uint);
    function collateral() virtual public view returns (address);
    function join(address, uint) virtual public payable;
    function exit(address, uint) virtual public;
}
