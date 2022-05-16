// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

pragma experimental ABIEncoderV2;

import "@ozUpgradesV3/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@ozUpgradesV3/contracts/token/ERC20/SafeERC20Upgradeable.sol";
import "@ozUpgradesV3/contracts/utils/AddressUpgradeable.sol";
import "@ozUpgradesV3/contracts/math/SafeMathUpgradeable.sol";
import "@ozUpgradesV3/contracts/access/OwnableUpgradeable.sol";
import "@ozUpgradesV3/contracts/utils/ReentrancyGuardUpgradeable.sol";

import "../../../interfaces/yearnV1/IVault.sol";
import "../../../interfaces/yearnV1/IVaultSavings.sol";

import "@ozUpgradesV3/contracts/utils/PausableUpgradeable.sol";

contract VaultSavings is IVaultSavings, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
    uint256 constant MAX_UINT256 = uint256(-1);

    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;

    struct VaultInfo {
        bool isActive;
        uint256 blockNumber;
    }

    address[] internal registeredVaults;
    mapping(address => VaultInfo) vaults;

    function initialize() public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    // deposit, withdraw

    function deposit(address[] calldata _vaults, uint256[] calldata _amounts) external override nonReentrant whenNotPaused {
        require(_vaults.length == _amounts.length, "Size of arrays does not match");

        for (uint256 i = 0; i < _vaults.length; i++) {
            _deposit(_vaults[i], _amounts[i]);
        }
    }

    function deposit(address _vault, uint256 _amount) external override nonReentrant whenNotPaused returns (uint256 lpAmount) {
        lpAmount = _deposit(_vault, _amount);
    }

    function _deposit(address _vault, uint256 _amount) internal returns (uint256 lpAmount) {
        //check vault
        require(isVaultRegistered(_vault), "Vault is not Registered");
        require(isVaultActive(_vault), "Vault is not Active");

        address baseToken = IVault(_vault).token();

        //transfer token if it is allowed to contract
        IERC20Upgradeable(baseToken).safeTransferFrom(msg.sender, address(this), _amount);

        //set allowence to vault
        IERC20Upgradeable(baseToken).safeIncreaseAllowance(_vault, _amount);

        //deposit token to vault
        IVault(_vault).deposit(_amount);

        lpAmount = IERC20Upgradeable(_vault).balanceOf(address(this));
        //send new tokens to user
        IERC20Upgradeable(_vault).safeTransfer(msg.sender, lpAmount);

        emit Deposit(_vault, msg.sender, _amount, lpAmount);
    }

    function withdraw(address[] calldata _vaults, uint256[] calldata _amounts) external override nonReentrant whenNotPaused {
        require(_vaults.length == _amounts.length, "Size of arrays does not match");

        for (uint256 i = 0; i < _vaults.length; i++) {
            _withdraw(_vaults[i], _amounts[i]);
        }
    }

    function withdraw(address _vault, uint256 _amount) external override nonReentrant whenNotPaused returns (uint256 baseAmount) {
        baseAmount = _withdraw(_vault, _amount);
    }

    function _withdraw(address _vault, uint256 _amount) internal returns (uint256 baseAmount) {
        require(isVaultRegistered(_vault), "Vault is not Registered");
        require(isVaultActive(_vault), "Vault is not Active");
        //transfer LP Token if it is allowed to contract
        IERC20Upgradeable(_vault).safeTransferFrom(msg.sender, address(this), _amount);

        //burn tokens from vault
        IVault(_vault).withdraw(_amount);

        address baseToken = IVault(_vault).token();

        baseAmount = IERC20Upgradeable(baseToken).balanceOf(address(this));

        //Transfer token to user
        IERC20Upgradeable(baseToken).safeTransfer(msg.sender, baseAmount);

        emit Withdraw(_vault, msg.sender, baseAmount, _amount);
    }

    function registerVault(address _vault) external override onlyOwner {
        require(!isVaultRegistered(_vault), "Vault is already registered");

        registeredVaults.push(_vault);

        vaults[_vault] = VaultInfo({isActive: true, blockNumber: block.number});

        address baseToken = IVault(_vault).token();

        emit VaultRegistered(_vault, baseToken);
    }

    function activateVault(address _vault) external override onlyOwner {
        require(isVaultRegistered(_vault), "Vault is not registered");

        vaults[_vault] = VaultInfo({isActive: true, blockNumber: block.number});

        emit VaultActivated(_vault);
    }

    function deactivateVault(address _vault) external override onlyOwner {
        require(isVaultRegistered(_vault), "Vault is not registered");

        vaults[_vault] = VaultInfo({isActive: false, blockNumber: block.number});

        emit VaultDisabled(_vault);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    //view functions
    function isVaultRegistered(address _vault) public view override returns (bool) {
        for (uint256 i = 0; i < registeredVaults.length; i++) {
            if (registeredVaults[i] == _vault) return true;
        }
        return false;
    }

    function isVaultActive(address _vault) public view override returns (bool) {
        return vaults[_vault].isActive;
    }

    function isBaseTokenForVault(address _vault, address _token) public view override returns (bool) {
        address baseToken = IVault(_vault).token();
        if (baseToken == _token) return true;
        return false;
    }

    function supportedVaults() external view override returns (address[] memory) {
        return registeredVaults;
    }

    function activeVaults() external view override returns (address[] memory _vaults) {
        uint256 j = 0;
        for (uint256 i = 0; i < registeredVaults.length; i++) {
            if (vaults[registeredVaults[i]].isActive) {
                j = j.add(1);
            }
        }
        if (j > 0) {
            _vaults = new address[](j);
            j = 0;
            for (uint256 i = 0; i < registeredVaults.length; i++) {
                if (vaults[registeredVaults[i]].isActive) {
                    _vaults[j] = registeredVaults[i];
                    j = j.add(1);
                }
            }
        }
    }
}
