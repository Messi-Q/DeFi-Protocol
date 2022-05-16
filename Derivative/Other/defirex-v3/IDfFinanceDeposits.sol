pragma solidity ^0.5.16;

interface IDfFinanceDeposits {

    enum FlashloanProvider {
        DYDX,
        AAVE,
        ADDRESS
    }

    function createStrategyDeposit(uint256 amountDAI, uint256 flashLoanAmount, address dfWallet) external returns (address);
    function createStrategyDepositFlashloan(uint256 amountDAI, uint256 flashLoanAmount, address dfWallet) external returns (address);
    function createStrategyDepositMulti(uint256 amountDAI, uint256 flashLoanAmount, uint32 times) external;

    function closeDepositDAI(address dfWallet, uint256 minDAIForCompound, bytes calldata data) external;
    function closeDepositFlashloan(address dfWallet, uint256 minUsdForComp, bytes calldata data) external;

    function partiallyCloseDepositDAI(address dfWallet, address tokenReceiver, uint256 amountDAI) external;
    function partiallyCloseDepositDAIFlashloan(address dfWallet, address tokenReceiver, uint256 amountDAI) external;

    function claimComps(address dfWallet, address[] calldata ctokens) external returns(uint256);

    function deposit(
        address dfWallet,
        uint256 amountDAI,
        uint256 amountUSDC,
        uint256 amountWBTC,
        uint256 flashloanDAI,
        uint256 flashloanUSDC,
        FlashloanProvider flashloanType,
        address flashloanFromAddress
    ) external payable returns(address);

    function withdraw(
        address dfWallet,
        uint256 amountDAI,
        uint256 amountUSDC,
        uint256 amountETH,
        uint256 amountWBTC,
        address receiver,
        uint256 flashloanDAI,
        uint256 flashloanUSDC,
        FlashloanProvider flashloanType,
        address flashloanFromAddress
    ) external;
}
