// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

import "@ozUpgradesV3/contracts/token/ERC20/ERC20Upgradeable.sol";
import "../../vakro/MinterRole.sol";

contract TestADEL is ERC20Upgradeable, MinterRole {
    string constant NAME = "Akropolis Delphi";
    string constant SYMBOL = "ADEL";
    uint8 constant DECIMALS = 18;

    function initialize() public initializer {
        ERC20Upgradeable.__ERC20_init(NAME, SYMBOL);
        _setupDecimals(DECIMALS);
        MinterRole.initialize(_msgSender());
    }

    function mint(uint256 amount) public onlyMinter {
        _mint(_msgSender(), amount);
    }

    function burn(uint256 amount) public onlyMinter {
        _burn(_msgSender(), amount);
    }
}
