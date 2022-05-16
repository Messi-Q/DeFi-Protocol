// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint8 _decimals
    ) public ERC20(name, symbol) {
        _setupDecimals(_decimals);
    }

    function mint(uint256 amount) public {
        _mint(_msgSender(), amount);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }
}
