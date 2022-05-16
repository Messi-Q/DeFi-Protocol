// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

//solhint-disable func-order
interface IVaultSavings {
    event VaultRegistered(address indexed vault, address baseToken);
    event VaultDisabled(address indexed vault);
    event VaultActivated(address indexed vault);

    event Deposit(address indexed vault, address indexed user, uint256 baseAmount, uint256 lpAmount);
    event Withdraw(address indexed vault, address indexed user, uint256 baseAmount, uint256 lpAmount);

    function deposit(address[] calldata _vaults, uint256[] calldata _amounts) external;

    function deposit(address _vault, uint256 _amount) external returns (uint256);

    function withdraw(address[] calldata _vaults, uint256[] calldata _amounts) external;

    function withdraw(address _vault, uint256 amount) external returns (uint256);

    function registerVault(address _vault) external;

    function activateVault(address _vault) external;

    function deactivateVault(address _vault) external;

    //view functions
    function isVaultRegistered(address _vault) external view returns (bool);

    function isVaultActive(address _vault) external view returns (bool);

    function isBaseTokenForVault(address _vault, address _token) external view returns (bool);

    function supportedVaults() external view returns (address[] memory);

    function activeVaults() external view returns (address[] memory);
}
