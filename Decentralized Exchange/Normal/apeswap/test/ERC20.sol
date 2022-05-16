pragma solidity =0.5.16;

import '../ApeERC20.sol';

contract ERC20 is ApeERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
