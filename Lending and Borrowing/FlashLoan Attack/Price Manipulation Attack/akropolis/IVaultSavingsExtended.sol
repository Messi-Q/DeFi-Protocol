// SPDX-License-Identifier: AGPL V3.0

pragma solidity >=0.6.0 <0.8.0;

//solhint-disable func-order
interface IVaultSavingsExtended {
    event DepositToken(address indexed vault, address indexed token, uint256 dnAmount);
    event WithdrawToken(address indexed vault, address indexed token, uint256 dnAmount);

    function deposit(
        address[] calldata _vaults,
        address[] calldata _tokens,
        uint256[] calldata _dnAmounts
    ) external;

    function deposit(
        address _vault,
        address[] memory _tokens,
        uint256[] memory _dnAmounts
    ) external;

    function addSupportTokensToVault(address _vault, address[] calldata _tokens) external;

    function isSupportTokenForVault(address _vault, address _token) external view returns (bool);

    function supportTokensForVault() external view returns (address[] memory);

    function withdraw(
        address _vault,
        address[] calldata _tokens,
        uint256[] calldata _amounts
    ) external returns (uint256);
}
