pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "../../access/FundsManager.sol";
import "../../access/Adminable.sol";

import "../../constants/ConstantAddressesMainnet.sol";

import "../../utils/DSMath.sol";
import "../../utils/SafeMath.sol";

import "../../flashloan/base/FlashLoanReceiverBase.sol";
import "../../dydxFlashloan/FlashloanDyDx.sol";

// **INTERFACES**
import "../../compound/interfaces/ICToken.sol";
import "../../flashloan/interfaces/ILendingPool.sol";
import "../../interfaces/IDfWalletFactory.sol";
import "../../interfaces/IDfWallet.sol";
import "../../interfaces/IToken.sol";
import "../../interfaces/IComptrollerLensInterface.sol";
import "../../interfaces/IComptroller.sol";
import "../../interfaces/IWeth.sol";
import "../../interfaces/IDfProxy.sol";


interface IUniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function factory() external view returns (address);
}

contract DfUserDeposits is
    Initializable,
    DSMath,
    ConstantAddresses,
    FundsManager,
    Adminable,
    FlashLoanReceiverBase,
    FlashloanDyDx
{
    using UniversalERC20 for IToken;
    using SafeMath for uint256;


    IUniswapV2Router02 constant uniRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // same for kovan and mainnet


    struct FlashloanData {
        address dfWallet;
        address token;
        address cToken;
        uint256 deposit;
        uint256 amountFlashLoan;
    }

    struct FlashloanDataDyDxEth {
        address dfWallet;
        address token;
        address cToken;
        uint256 deposit;
        uint256 debt;
        uint256 ethAmountFlashLoan;
    }

    // ** ENUMS **

    enum OP {
        UNKNOWN,
        DEPOSIT,
        WITHDRAW,
        DEPOSIT_USING_DYDX_ETH,
        WITHDRAW_USING_DYDX_ETH
    }

    enum FlashloanProvider {
        DYDX,
        AAVE,
        ADDRESS
    }


    // ** PUBLIC STATES **

    IDfWalletFactory public dfWalletFactory;

    // token => ctoken
    mapping(address => address) public ctokens;
    mapping(address => bool) public approvedTokens;
    // wallet => user
    mapping(address => address) public walletOwner;
    uint256 public fee;


    // ** PRIVATE STATES **

    OP private state;

    // ** ADDED STATES **
    // withdraw min ratio from cToken to Token conversion
    uint256 public withdrawMinRatio;

    event Profit(address indexed userAddress, address indexed token, uint256 profit);

    // ** EVENTS **

    // ** INITIALIZER – Constructor for Upgradable contracts **

    function initialize() public initializer {
        Adminable.initialize();  // Initialize Parent Contract
        // FundsManager.initialize();  // Init in Adminable

        withdrawMinRatio = 0.995 * 1e18;
        fee = 10;
    }


    // ** ONLY_OWNER functions **

    function setDfWalletFactory(address _dfWalletFactory) public onlyOwner {
        require(_dfWalletFactory != address(0));
        dfWalletFactory = IDfWalletFactory(_dfWalletFactory);
    }

    function setFee(uint256 _fee) public onlyOwner {
        require(_fee < 50);
        fee = _fee;
    }

    function approveTokens(address[] memory _tokens, bool _approve) public onlyOwner {
        uint256 len = _tokens.length;
        for(uint256 i = 0; i < len;i++) approvedTokens[_tokens[i]] = _approve;
    }

    function setCTokens(address[] memory _tokens, address[] memory _cTokens) public onlyOwner {
        uint256 len = _tokens.length;
        require(len == _cTokens.length);
        for(uint256 i = 0; i < len;i++) ctokens[_tokens[i]] = _cTokens[i];
    }

    function setWithdrawMinRatio(uint256 _withdrawMinRatio) public onlyOwner {
        require(_withdrawMinRatio >= 0.9 * 1e18 && _withdrawMinRatio <= 1e18);
        withdrawMinRatio = _withdrawMinRatio;
    }


    // ** PUBLIC functions **

    function getCompBalanceMetadataExt(address account) external returns (uint256 balance, uint256 allocated) {
        IComptrollerLensInterface comptroller = IComptrollerLensInterface(COMPTROLLER);
        balance = IToken(COMP_ADDRESS).balanceOf(account);
        comptroller.claimComp(account);
        uint256 newBalance = IToken(COMP_ADDRESS).balanceOf(account);
        uint256 accrued = comptroller.compAccrued(account);
        uint256 total = add(accrued, newBalance);
        allocated = sub(total, balance);
    }


    // DEPOSIT function

    function deposit(
        address dfWallet,
        address depositTokenAddress,
        uint256 _amountDeposit,
        address boostTokenAddress,
        uint256 _amountBoostDeposit,
        uint256 _amountBoost,
        FlashloanProvider flashloanType,
        address flashloanFromAddress,
        bool bCheckLiquidity
    ) public payable onlyOwnerOrAdmin returns (uint256 liquidity) {
        if (dfWallet == address(0)) {
            dfWallet = dfWalletFactory.createDfWallet();
            walletOwner[dfWallet] = msg.sender;
        }

        require(walletOwner[dfWallet] == msg.sender);

        address _ctokenDepositAddress = ctokens[depositTokenAddress];
        require(_ctokenDepositAddress != address(0));

        address _ctokenBoostAddress = ctokens[boostTokenAddress];
        require(_ctokenBoostAddress != address(0));

        uint amountETH = msg.value;

        // Update states
//        wallets[dfWallet][tokenAddress]= add(wallets[dfWallet][tokenAddress], _amountDeposit);

        // Deposit asset without boosting
        if (amountETH > 0 && depositTokenAddress == ETH_ADDRESS) {
            IDfWallet(dfWallet).deposit.value(amountETH)(depositTokenAddress, _ctokenDepositAddress, amountETH, address(0), address(0), 0);
        } else if (_amountDeposit > 0){
            IToken(depositTokenAddress).universalTransferFrom(msg.sender, dfWallet, _amountDeposit);
            IDfWallet(dfWallet).deposit(depositTokenAddress, _ctokenDepositAddress, _amountDeposit, address(0), address(0), 0);
        }

        // Boost
        if (_amountBoost > 0) {
            if (_amountBoostDeposit > 0) IToken(boostTokenAddress).universalTransferFrom(msg.sender, dfWallet, _amountBoostDeposit);
            if (flashloanType == FlashloanProvider.DYDX
                && _amountBoost > IToken(boostTokenAddress).balanceOf(SOLO_MARGIN_ADDRESS)
            ) {
                // if dYdX lacks liquidity in USDC use ETH
                _depositBoostUsingDyDxEth(
                    dfWallet, boostTokenAddress, _ctokenBoostAddress, _amountBoostDeposit, _amountBoost
                );
            } else {
                _depositBoost(
                    dfWallet, boostTokenAddress, _ctokenBoostAddress, _amountBoostDeposit, _amountBoost, flashloanType, flashloanFromAddress
                );
            }
        }

        if (bCheckLiquidity) {
            (,liquidity,) = IComptroller(COMPTROLLER).getAccountLiquidity(dfWallet);
        }
    }


    // CLAIM function

    function claimComps(address dfWallet, address[] memory cTokens, address[] memory path, uint256 _minAmount) public returns(uint256) {
        require(walletOwner[dfWallet] == msg.sender);

        IDfWallet(dfWallet).claimComp(cTokens);

        if (IToken(COMP_ADDRESS).allowance(address(this), address(uniRouter)) != uint256(-1)) {
            IToken(COMP_ADDRESS).approve(address(uniRouter), uint256(-1));
        }

        require(path[0] == COMP_ADDRESS);
        uint256 len = path.length;
        require(len > 1);
        for(uint256 i = 1; i < len;i++) require(approvedTokens[path[i]]);

        uniRouter.swapExactTokensForTokens(IToken(COMP_ADDRESS).balanceOf(address(this)), _minAmount, path, address(this), now + 1000);

        address targetToken = path[len - 1];
        uint256 bal = IToken(targetToken).balanceOf(address(this));
        uint256 _fee = bal * fee / 100;
        IToken(targetToken).universalTransfer(owner, _fee);
        bal = bal.sub(_fee);
        IToken(targetToken).universalTransfer(msg.sender, bal);

        emit Profit(msg.sender, targetToken, bal);
        return bal;
    }


    // WITHDRAW function

    function withdraw(
        address dfWallet,
        address depositTokenAddress,
        uint256 _amountDeposit,
        address boostTokenAddress,
        uint256 _amountBoostDeposited,
        uint256 _amountBoost,
        address receiver,
        FlashloanProvider flashloanType,
        address flashloanFromAddress,
        bool bCheckLiquidity
    ) public onlyOwnerOrAdmin returns (uint256 liquidity, uint256 shortfall){
        require(walletOwner[dfWallet] == msg.sender);
        require(receiver != address(0));

        address _ctokenDepositAddress = ctokens[depositTokenAddress];
        require(_ctokenDepositAddress != address(0));

        address _ctokenBoostAddress = ctokens[boostTokenAddress];
        require(_ctokenBoostAddress != address(0));

        if (_amountBoost > 0) {
            // Withdraw assets
            _withdrawBoostedAsset(
                dfWallet, boostTokenAddress, _ctokenBoostAddress, _amountBoostDeposited, receiver, _amountBoost, flashloanType, flashloanFromAddress
            );
        }

        if (_amountDeposit > 0) {
            _withdrawAsset(
                dfWallet, depositTokenAddress, _ctokenDepositAddress, _amountDeposit, receiver
            );
        }


        if (bCheckLiquidity) {
            (, liquidity, shortfall) = IComptroller(COMPTROLLER).getAccountLiquidity(dfWallet);
        }
    }


    // ** FLASHLOAN CALLBACK functions **

    // Aave flashloan callback
    function executeOperation(
        address _reserve,
        uint256 _amountFlashLoan,
        uint256 _fee,
        bytes memory _data
    ) public {
        _flashloanHandler(_data, _fee);

        // Time to transfer the funds back
        transferFundsBackToPoolInternal(_reserve, add(_amountFlashLoan, _fee));
    }

    // dYdX flashloan callback
    function callFunction(
        address sender,
        Account.Info memory account,
        bytes memory data
    ) public {
        _flashloanHandler(data, 0);
    }


    // ** PRIVATE & INTERNAL functions **

    function _bytesToAddress(bytes memory bys) private pure returns (address addr) {
        assembly {
            addr := mload(add(bys,20))
        }
    }

    function _depositBoost(
        address dfWallet,
        address token,
        address cToken,
        uint256 deposit,
        uint256 flashloanAmount,
        FlashloanProvider flashloanType,
        address flashloanFromAddress
    ) internal {
        // FLASHLOAN LOGIC
        state = OP.DEPOSIT;

        if (flashloanType == FlashloanProvider.DYDX) {
            _initFlashloanDyDx(
                token,
                flashloanAmount,
                // Encode FlashloanData for callFunction
                abi.encode(FlashloanData({dfWallet: dfWallet, token: token, cToken: cToken, deposit: deposit, amountFlashLoan: flashloanAmount}))
            );
        } else if (flashloanType == FlashloanProvider.AAVE) {
            ILendingPool lendingPool = ILendingPool(ILendingPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getLendingPool());
            lendingPool.flashLoan(
                address(this),
                token,
                flashloanAmount,
                // Encode FlashloanData for executeOperation
                abi.encode(FlashloanData({dfWallet: dfWallet, token: token, cToken: cToken, deposit: deposit, amountFlashLoan: flashloanAmount}))
            );
        } else if (flashloanType == FlashloanProvider.ADDRESS) {
            IToken(token).universalTransferFrom(flashloanFromAddress, dfWallet, flashloanAmount);

            IDfWallet(dfWallet).deposit(token, cToken, add(deposit, flashloanAmount), token, cToken, flashloanAmount);
            IDfWallet(dfWallet).withdrawToken(token, flashloanFromAddress, flashloanAmount);
        }

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC
    }

    function _depositBoostUsingDyDxEth(
        address dfWallet,
        address token,
        address cToken,
        uint256 deposit,
        uint256 flashloanInTokens
    ) internal {
        // FLASHLOAN LOGIC
        state = OP.DEPOSIT_USING_DYDX_ETH;

        IPriceOracle compOracle = IComptroller(COMPTROLLER).oracle();
        uint256 ethPrice = compOracle.price("ETH").mul(1e12); // with 1e18 (1e6 * 1e12)

        uint256 ethDecimals = 18;
        uint256 decimalsMultiplier = 10 ** ethDecimals.sub(IToken(token).decimals());

        // IMPORTANT: token price is equal to 1 USD
        uint256 flashloanEthAmount = wdiv(flashloanInTokens * decimalsMultiplier, ethPrice).mul(2); // use x2 coef for eth as collateral

        _initFlashloanDyDx(
            WETH_ADDRESS,
            flashloanEthAmount,
            // Encode FlashloanDataDyDxEth for callFunction
            abi.encode(FlashloanDataDyDxEth({
                dfWallet: dfWallet, token: token, cToken: cToken, deposit: deposit, debt: flashloanInTokens, ethAmountFlashLoan: flashloanEthAmount
            }))
        );

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC
    }

    function _withdrawBoostedAsset(
        address dfWallet,
        address token,
        address cToken,
        uint256 amountToken,
        address receiver,
        uint256 flashloanAmount,
        FlashloanProvider flashloanType,
        address flashloanFromAddress
    ) internal {
        if (amountToken == 0 && flashloanAmount == 0) {
            return;
        }

        if (IToken(token).allowance(address(this), dfWallet) != uint(-1)) {
            IToken(token).approve(dfWallet, uint(-1));
        }

        uint startBalance = IToken(token).universalBalanceOf(address(this));

        if (flashloanType == FlashloanProvider.DYDX
            && flashloanAmount > IToken(token).balanceOf(SOLO_MARGIN_ADDRESS)
        ) {
            // if dYdX lacks liquidity in token (DAI or USDC) use ETH
            _withdrawBoostUsingDyDxEth(
                dfWallet, token, cToken, amountToken, flashloanAmount
            );
        } else {
            _withdrawBoost(
                dfWallet, token, cToken, amountToken, flashloanAmount, flashloanType, flashloanFromAddress
            );
        }

        uint curBalance = IToken(token).universalBalanceOf(address(this));

        // rounding in token to cToken conversion
        if (curBalance <= startBalance) {
            require(wdiv(curBalance, startBalance) >= withdrawMinRatio);
            return;
        }

        uint tokensToUser = sub(curBalance, startBalance);
        if (token == ETH_ADDRESS) {
            _transferEth(receiver, tokensToUser);
        } else {
            IToken(token).universalTransfer(receiver, tokensToUser);
        }
    }

    function _withdrawAsset(
        address dfWallet,
        address token,
        address cToken,
        uint256 amountToken,
        address receiver
    ) internal {
        if (amountToken == 0) {
            return;
        }

        uint startBalance = IToken(token).universalBalanceOf(address(this));

        // Compound Quick Maths – redeemAmountIn * 1e18 * 1e18 / exchangeRateCurrent / 1e18
        uint cTokenToExtract =  (amountToken != uint(-1)) ? amountToken.mul(1e36).div(ICToken(cToken).exchangeRateCurrent()).div(1e18) : uint(-1);
        IDfWallet(dfWallet).withdraw(token, cToken, cTokenToExtract, ETH_ADDRESS, CETH_ADDRESS, 0);

        uint tokensToUser = sub(IToken(token).universalBalanceOf(address(this)), startBalance);
        if (token == ETH_ADDRESS) {
            _transferEth(receiver, tokensToUser);
        } else {
            IToken(token).universalTransfer(receiver, tokensToUser);
        }
    }

    function _withdrawBoost(
        address dfWallet,
        address token,
        address cToken,
        uint256 deposit,
        uint256 flashloanAmount,
        FlashloanProvider flashloanType,
        address flashloanFromAddress
    ) internal {
        // FLASHLOAN LOGIC
        state = OP.WITHDRAW;

        if (flashloanType == FlashloanProvider.DYDX) {
            _initFlashloanDyDx(
                token,
                flashloanAmount,
                // Encode FlashloanData for callFunction
                abi.encode(FlashloanData({dfWallet: dfWallet, token: token, cToken: cToken, deposit: deposit, amountFlashLoan: flashloanAmount}))
            );
        } else if (flashloanType == FlashloanProvider.AAVE) {
            ILendingPool lendingPool = ILendingPool(ILendingPoolAddressesProvider(AAVE_ADDRESSES_PROVIDER).getLendingPool());
            lendingPool.flashLoan(
                address(this),
                token,
                flashloanAmount,
                // Encode FlashloanData for executeOperation
                abi.encode(FlashloanData({dfWallet: dfWallet, token: token, cToken: cToken, deposit: deposit, amountFlashLoan: flashloanAmount}))
            );
        } else if (flashloanType == FlashloanProvider.ADDRESS) {
            IToken(token).universalTransferFrom(flashloanFromAddress, dfWallet, flashloanAmount);

            // Compound Quick Maths – redeemAmountIn * 1e18 * 1e18 / exchangeRateCurrent / 1e18
            uint cTokenToExtract = (deposit != uint(-1)) ? deposit.add(flashloanAmount).mul(1e36).div(ICToken(cToken).exchangeRateCurrent()).div(1e18) : uint(-1);
            IDfWallet(dfWallet).withdraw(token, cToken, cTokenToExtract, token, cToken, flashloanAmount);

            IToken(token).universalTransfer(flashloanFromAddress, flashloanAmount);
        }

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC
    }

    function _withdrawBoostUsingDyDxEth(
        address dfWallet,
        address token,
        address cToken,
        uint256 deposit,
        uint256 flashloanInTokens
    ) internal {
        // FLASHLOAN LOGIC
        state = OP.WITHDRAW_USING_DYDX_ETH;

        IPriceOracle compOracle = IComptroller(COMPTROLLER).oracle();
        uint256 ethPrice = compOracle.price("ETH").mul(1e12); // with 1e18 (1e6 * 1e12)

        uint256 ethDecimals = 18;
        uint256 decimalsMultiplier = 10 ** ethDecimals.sub(IToken(token).decimals());

        // IMPORTANT: token price is equal to 1 USD
        uint256 flashloanEthAmount = wdiv(flashloanInTokens * decimalsMultiplier, ethPrice).mul(2); // use x2 coef for eth as collateral

        _initFlashloanDyDx(
            WETH_ADDRESS,
            flashloanEthAmount,
            // Encode FlashloanDataDyDxEth for callFunction
            abi.encode(FlashloanDataDyDxEth({
                dfWallet: dfWallet, token: token, cToken: cToken, deposit: deposit, debt: flashloanInTokens, ethAmountFlashLoan: flashloanEthAmount
            }))
        );

        state = OP.UNKNOWN;
        // END FLASHLOAN LOGIC
    }

    function _flashloanHandler(
        bytes memory data,
        uint fee
    ) internal {
        require(state != OP.UNKNOWN);

        if (state == OP.DEPOSIT) {
            FlashloanData memory flashloanData = abi.decode(data, (FlashloanData));

            // Calculate repay amount
            uint totalDebt = add(flashloanData.amountFlashLoan, fee);

            IToken(flashloanData.token).transfer(flashloanData.dfWallet, flashloanData.amountFlashLoan);

            IDfWallet(flashloanData.dfWallet).deposit(
                flashloanData.token, flashloanData.cToken, add(flashloanData.deposit, flashloanData.amountFlashLoan), flashloanData.token, flashloanData.cToken, totalDebt
            );

            IDfWallet(flashloanData.dfWallet).withdrawToken(flashloanData.token, address(this), totalDebt);
        } else if (state == OP.WITHDRAW) {
            FlashloanData memory flashloanData = abi.decode(data, (FlashloanData));

            // _withdrawBoost() subtracts flashloan fee
            // Compound Quick Maths – redeemAmountIn * 1e18 * 1e18 / exchangeRateCurrent / 1e18
            uint cTokenToExtract = (flashloanData.deposit != uint(-1)) ? flashloanData.deposit.add(flashloanData.amountFlashLoan).mul(1e36).div(ICToken(flashloanData.cToken).exchangeRateCurrent()).div(1e18) : uint(-1);

            IDfWallet(flashloanData.dfWallet).withdraw(flashloanData.token, flashloanData.cToken, cTokenToExtract, flashloanData.token, flashloanData.cToken, flashloanData.amountFlashLoan);
            // require(flashloanData.amountFlashLoan.div(3) >= sub(receivedAmount, _fee), "Fee greater then user amount"); // user pay fee for flash loan
        } else if (state == OP.DEPOSIT_USING_DYDX_ETH) {
            // use dYdX flashloans without fee
            FlashloanDataDyDxEth memory flashloanData = abi.decode(data, (FlashloanDataDyDxEth));
            uint256 loanEth = flashloanData.ethAmountFlashLoan;

            // WETH to ETH for loan using proxy (eth transfer gas limit)
            IDfProxy dfProxy = IDfProxy(DF_PROXY_ADDRESS);
            IERC20(WETH_ADDRESS).transfer(address(dfProxy), loanEth);
            dfProxy.cast(address(uint160(WETH_ADDRESS)), abi.encodeWithSelector(IWeth(WETH_ADDRESS).withdraw.selector, loanEth));
            dfProxy.withdrawEth(address(this));

            // deposit eth loan and borrow debt tokens
            IDfWallet(flashloanData.dfWallet).deposit.value(loanEth)(
                ETH_ADDRESS, CETH_ADDRESS, loanEth, flashloanData.token, flashloanData.cToken, flashloanData.debt
            );

            // deposit user deposit + debt tokens (are already on the dfWallet)
            IDfWallet(flashloanData.dfWallet).deposit(
                flashloanData.token, flashloanData.cToken, add(flashloanData.deposit, flashloanData.debt), address(0), address(0), 0
            );

            // redeem eth loan (using withdraw function)
            // Compound Quick Maths – redeemAmountIn * 1e18 * 1e18 / exchangeRateCurrent / 1e18
            uint cEthToExtract = loanEth.mul(1e36).div(ICToken(CETH_ADDRESS).exchangeRateCurrent()).div(1e18);
            IDfWallet(flashloanData.dfWallet).withdraw(
                ETH_ADDRESS, CETH_ADDRESS, cEthToExtract, ETH_ADDRESS, CETH_ADDRESS, 0
            );

            // ETH to WETH for loan
            IWeth(WETH_ADDRESS).deposit.value(loanEth)();
        } else if (state == OP.WITHDRAW_USING_DYDX_ETH) {
            // use dYdX flashloans without fee
            FlashloanDataDyDxEth memory flashloanData = abi.decode(data, (FlashloanDataDyDxEth));
            uint256 loanEth = flashloanData.ethAmountFlashLoan;

            // WETH to ETH for loan using proxy (eth transfer gas limit)
            IDfProxy dfProxy = IDfProxy(DF_PROXY_ADDRESS);
            IERC20(WETH_ADDRESS).transfer(address(dfProxy), loanEth);
            dfProxy.cast(address(uint160(WETH_ADDRESS)), abi.encodeWithSelector(IWeth(WETH_ADDRESS).withdraw.selector, loanEth));
            dfProxy.withdrawEth(address(this));

            // deposit eth loan and borrow debt tokens
            IDfWallet(flashloanData.dfWallet).deposit.value(loanEth)(
                ETH_ADDRESS, CETH_ADDRESS, loanEth, flashloanData.token, flashloanData.cToken, flashloanData.debt
            );
            IDfWallet(flashloanData.dfWallet).withdrawToken(flashloanData.token, address(this), flashloanData.debt);

            // repay debt tokens and redeem deposit + debt tokens
            // Compound Quick Maths – redeemAmountIn * 1e18 * 1e18 / exchangeRateCurrent / 1e18
            uint cTokenToExtract = (flashloanData.deposit != uint(-1)) ? flashloanData.deposit.add(flashloanData.debt).mul(1e36).div(ICToken(flashloanData.cToken).exchangeRateCurrent()).div(1e18) : uint(-1);
            IDfWallet(flashloanData.dfWallet).withdraw(
                flashloanData.token, flashloanData.cToken, cTokenToExtract, flashloanData.token, flashloanData.cToken, flashloanData.debt
            );

            // repay debt tokens and redeem eth loan
            // Compound Quick Maths – redeemAmountIn * 1e18 * 1e18 / exchangeRateCurrent / 1e18
            uint cEthToExtract = loanEth.mul(1e36).div(ICToken(CETH_ADDRESS).exchangeRateCurrent()).div(1e18);
            IDfWallet(flashloanData.dfWallet).withdraw(
                ETH_ADDRESS, CETH_ADDRESS, cEthToExtract, flashloanData.token, flashloanData.cToken, flashloanData.debt
            );

            // ETH to WETH for loan
            IWeth(WETH_ADDRESS).deposit.value(loanEth)();
        }
    }

    function _transferEth(address _receiver, uint _amount) internal {
        address payable receiverPayable = address(uint160(_receiver));
        (bool result, ) = receiverPayable.call.value(_amount)("");
        require(result, "Transfer of ETH failed");
    }


    // **FALLBACK functions**
    function() external payable {}

}
