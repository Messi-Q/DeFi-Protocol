// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.7.4;

import "./IProxyAdmin.sol";

interface IVariables {
    function owner() external view returns (address);

    /**
     * @notice Get the address of the vault
     * @return address The address of the vault
     */
    function getVault() external view returns (address);

    /**
     * @notice Get the vault fee rate
     * @return int256 The vault fee rate
     */
    function getVaultFeeRate() external view returns (int256);

    /**
     * @notice Get the address of the access controller. It's always its own address.
     *
     * @return address The address of the access controller.
     */
    function getAccessController() external view returns (address);

    /**
     * @notice  Get the address of the symbol service.
     *
     * @return  Address The address of the symbol service.
     */
    function getSymbolService() external view returns (address);

    /**
     * @notice  Set the vault address. Can only called by owner.
     *
     * @param   newVault    The new value of the vault fee rate
     */
    function setVault(address newVault) external;

    /**
     * @notice  Get the address of the mcb token.
     * @dev     [ConfirmBeforeDeployment]
     *
     * @return  Address The address of the mcb token.
     */
    function getMCBToken() external pure returns (address);

    /**
     * @notice  Set the vault fee rate. Can only called by owner.
     *
     * @param   newVaultFeeRate The new value of the vault fee rate
     */
    function setVaultFeeRate(int256 newVaultFeeRate) external;
}
