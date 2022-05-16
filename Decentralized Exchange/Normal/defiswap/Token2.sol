//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token2 is ERC20 {

    address public minter;

    mapping(address => uint) public balances;

    constructor() payable ERC20("Token2", "TK2") {
        _mint(msg.sender, 100000000); //initial supply of 1 000 000 tokens
        minter = msg.sender;
    }

    function decimals() public view virtual override returns (uint8) {
        return 2;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == minter, "you are not the owner!");
        _mint(to, amount*10**2);
    }
}