// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IVaultV2 {
    // ERC20 part
    function balanceOf(address) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    // VaultV2 view interface
    function totalDebt() external view returns (uint256);

    function creditAvailable(address strategy) external view returns (uint256);

    function debtOutstanding(address strategy) external view returns (uint256);

    function emergencyShutdown() external view returns (bool);

    function token() external view returns (address);

    function governance() external view returns (address);

    function management() external view returns (address);

    function guardian() external view returns (address);

    // VaultV2 user interface
    function deposit(uint256 _amount, address recipient) external returns (uint256);

    function withdraw(
        uint256 maxShares,
        address recipient,
        uint256 maxLoss
    ) external returns (uint256);
}
