pragma solidity ^0.5.16;

interface IDfInfo {
    function getInfo(address dfTokenizedDepositAddress)
        external
        returns (
            uint256 liquidity,
            uint256 shortfall,
            uint256 land,
            uint256 cred,
            uint256 f,
            uint256[3] memory walletBalances,
            uint256[3] memory unwindedBalances,
            uint256[3] memory tokenBalances
        );

    function getCRate(address dfTokenizedDepositAddress) external returns (uint256 f);
}
