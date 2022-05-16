// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

contract TestShareToken is
    Initializable,
    ContextUpgradeable,
    AccessControlUpgradeable,
    ERC20Upgradeable
{
    function initialize(
        string memory name,
        string memory symbol,
        address admin
    ) public virtual initializer {
        __ShareToken_init(name, symbol, admin);
    }

    function __ShareToken_init(
        string memory name,
        string memory symbol,
        address admin
    ) internal initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __ShareToken_init_unchained(admin);
    }

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    function __ShareToken_init_unchained(address admin) internal initializer {
        _setupRole(ADMIN_ROLE, admin);
    }

    function debugMint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function mint(address account, uint256 amount) public virtual {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have admin role to mint"
        );
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) public virtual {
        require(
            hasRole(ADMIN_ROLE, _msgSender()),
            "ERC20PresetMinterPauser: must have admin role to burn"
        );
        _burn(account, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }

    uint256[50] private __gap;
}
