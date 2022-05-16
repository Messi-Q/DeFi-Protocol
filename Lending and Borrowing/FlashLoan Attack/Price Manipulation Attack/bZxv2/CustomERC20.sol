// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts/presets/ERC20PresetMinterPauser.sol";

contract CustomERC20 is ERC20PresetMinterPauser {
    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals
    ) ERC20PresetMinterPauser(name, symbol) {
        _setupDecimals(tokenDecimals);
    }
}
