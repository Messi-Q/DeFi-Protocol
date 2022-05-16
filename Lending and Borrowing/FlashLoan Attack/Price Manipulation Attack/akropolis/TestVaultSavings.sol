// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

import "../../yearnV1/vault-savings/VaultSavings.sol";

contract TestVaultSavings is VaultSavings {
    address public _deployer = 0x260dfB806B62baeBe10083142499f863528dD190;

    constructor() public {
        VaultSavings.initialize();
    }

    function echidna_vault_owner() public view returns (bool) {
        return owner() == _deployer;
    }
}
