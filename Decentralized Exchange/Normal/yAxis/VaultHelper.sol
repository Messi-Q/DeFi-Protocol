// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "./interfaces/ILiquidityGaugeV2.sol";
import "./interfaces/IVault.sol";

/**
 * @title VaultHelper
 * @notice The VaultHelper acts as a single contract that users may set
 * token approvals on for any token of any vault.
 * @dev This contract has no state and could be deployed by anyone if
 * they didn't trust the original deployer.
 */
contract VaultHelper {
    using SafeERC20 for IERC20;

    /**
     * @notice Deposits the given token into the specified vault
     * @dev Users must approve the vault helper to spend their token
     * @param _vault The address of the vault
     * @param _token The address of the token
     * @param _amount The amount of tokens to deposit
     */
    function depositVault(
        address _vault,
        address _token,
        uint256 _amount
    )
        external
    {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_token).safeApprove(_vault, 0);
        IERC20(_token).safeApprove(_vault, _amount);
        uint256 _shares = IVault(_vault).deposit(_token, _amount);
        address _gauge = IVault(_vault).gauge();
        if (_gauge != address(0)) {
            IERC20(_vault).safeApprove(_gauge, 0);
            IERC20(_vault).safeApprove(_gauge, _shares);
            ILiquidityGaugeV2(_gauge).deposit(_shares);
            IERC20(_gauge).safeTransfer(msg.sender, _shares);
        } else {
            IERC20(_vault).safeTransfer(msg.sender, _shares);
        }
    }

    /**
     * @notice Deposits multiple tokens simultaneously to the specified vault
     * @dev Users must approve the vault helper to spend their tokens
     * @param _vault The address of the vault
     * @param _tokens The addresses of each token being deposited
     * @param _amounts The amounts of each token being deposited
     */
    function depositMultipleVault(
        address _vault,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    )
        external
    {
        for (uint8 i = 0; i < _amounts.length; i++) {
            IERC20(_tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            IERC20(_tokens[i]).safeApprove(_vault, 0);
            IERC20(_tokens[i]).safeApprove(_vault, _amounts[i]);
        }
        uint256 _shares = IVault(_vault).depositMultiple(_tokens, _amounts);
        address _gauge = IVault(_vault).gauge();
        if (_gauge != address(0)) {
            IERC20(_vault).safeApprove(_gauge, 0);
            IERC20(_vault).safeApprove(_gauge, _shares);
            ILiquidityGaugeV2(_gauge).deposit(_shares);
            IERC20(_gauge).safeTransfer(msg.sender, _shares);
        } else {
            IERC20(_vault).safeTransfer(msg.sender, _shares);
        }
    }

    function withdrawVault(
        address _vault,
        address _toToken,
        uint256 _amount
    )
        external
    {
        address _gauge = IVault(_vault).gauge();
        if (_gauge != address(0)) {
            IERC20(_gauge).safeTransferFrom(msg.sender, address(this), _amount);
            ILiquidityGaugeV2(_gauge).withdraw(_amount);
            IVault(_vault).withdraw(IERC20(_vault).balanceOf(address(this)), _toToken);
            IERC20(_toToken).safeTransfer(msg.sender, IERC20(_toToken).balanceOf(address(this)));
        } else {
            IERC20(_vault).safeTransferFrom(msg.sender, address(this), _amount);
            IVault(_vault).withdraw(_amount, _toToken);
            IERC20(_toToken).safeTransfer(msg.sender, IERC20(_toToken).balanceOf(address(this)));
        }
    }
}
