pragma solidity ^0.5.16;

import "../constants/ConstantAddressesMainnet.sol";

import "../interfaces/IERC20.sol";
import "../interfaces/IDfTokenizedDeposit.sol";
import "../compound/interfaces/ICToken.sol";
import "../interfaces/IComptroller.sol";

contract DfInfo is ConstantAddresses {
    function getInfo(IDfTokenizedDeposit dfTokenizedDepositAddress)
        public
        returns (
            uint256 liquidity,
            uint256 shortfall,
            uint256 land,
            uint256 cred,
            uint256 f,
            uint256[3] memory walletBalances,
            uint256[3] memory unwindedBalances,
            uint256[3] memory tokenBalances
        )
    {
        address walletAddress = dfTokenizedDepositAddress.dfWallet();
        uint256 err;
        (err, liquidity, shortfall) = IComptroller(COMPTROLLER)
            .getAccountLiquidity(walletAddress);

        IPriceOracle compOracle = IComptroller(COMPTROLLER).oracle();

        walletBalances[0] = ICToken(CDAI_ADDRESS).balanceOfUnderlying(
            walletAddress
        );
        walletBalances[1] = ICToken(CWBTC_ADDRESS).balanceOfUnderlying(
            walletAddress
        );
        walletBalances[2] = ICToken(CETH_ADDRESS).balanceOfUnderlying(
            walletAddress
        );
        // land and cred are virtual $ with 18 decimals
        land =
            (walletBalances[0] * compOracle.price("DAI")) / 10**6 + // 18(DAI) + 6 - 6 = 18
            (walletBalances[1] * compOracle.price("BTC")) * 10**4 + // 8(WBTC) + 6 + 4 = 18
            (walletBalances[2] * compOracle.price("ETH")) / 10**6;  // 18(ETH) + 6 - 6 = 18

        cred = (ICToken(CDAI_ADDRESS).borrowBalanceCurrent(walletAddress)
                                * compOracle.price("DAI")) / 10**6; // 18(DAI) + 6 - 6 = 18

        walletBalances[0] -= ICToken(CDAI_ADDRESS).borrowBalanceCurrent(
            walletAddress
        );
        walletBalances[1] -= ICToken(CWBTC_ADDRESS).borrowBalanceCurrent(
            walletAddress
        );
        walletBalances[2] -= ICToken(CETH_ADDRESS).borrowBalanceCurrent(
            walletAddress
        );

        unwindedBalances[0] = dfTokenizedDepositAddress.fundsUnwinded(
            DAI_ADDRESS
        );
        unwindedBalances[1] = dfTokenizedDepositAddress.fundsUnwinded(
            WBTC_ADDRESS
        );
        unwindedBalances[2] = dfTokenizedDepositAddress.fundsUnwinded(
            WETH_ADDRESS
        );

        tokenBalances[0] = dfTokenizedDepositAddress.token().totalSupply();
        tokenBalances[1] = dfTokenizedDepositAddress.tokenWBTC().totalSupply();
        tokenBalances[2] = dfTokenizedDepositAddress.tokenETH().totalSupply();

        f = (cred * 100 * 1000) / land; // *1000 = 3 decimals (72.345 = 72345)
    }

    function getCRate(IDfTokenizedDeposit dfTokenizedDepositAddress)
    public
    returns (uint256 f)
    {
        address walletAddress = dfTokenizedDepositAddress.dfWallet();

        IPriceOracle compOracle = IComptroller(COMPTROLLER).oracle();

        uint256 daiPrice = compOracle.price("DAI");
        uint256 btcPrice = compOracle.price("BTC");
        uint256 ethPrice = compOracle.price("ETH");

        // land and cred are virtual $ with 18 decimals
        uint land =
        (ICToken(CDAI_ADDRESS).balanceOfUnderlying(walletAddress) * daiPrice)  / 10**6 + // 18(DAI) + 6 - 6 = 18
        (ICToken(CWBTC_ADDRESS).balanceOfUnderlying(walletAddress) * btcPrice) * 10**4 + // 8(WBTC) + 6 + 4 = 18
        (ICToken(CETH_ADDRESS).balanceOfUnderlying(walletAddress) * ethPrice)  / 10**6;  // 18(ETH) + 6 - 6 = 18

        uint cred =
        (ICToken(CDAI_ADDRESS).borrowBalanceCurrent(walletAddress) * daiPrice) / 10**6;  // 18(DAI) + 6 - 6 = 18

        f = (cred * 100 * 1000) / land; // *1000 = 3 decimals (72.345 = 72345)
    }
}
