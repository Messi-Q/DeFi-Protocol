pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "../access/Adminable.sol";

import "./DfProfits.sol";

import "../utils/DSMath.sol";

import "../constants/ConstantAddressesMainnet.sol";

import "../compound/interfaces/ICToken.sol";
import "../interfaces/IDfFinanceDeposits.sol";
import "../interfaces/IToken.sol";
import "../interfaces/IDfDepositToken.sol";
import "../interfaces/IPriceOracle.sol";
import "../interfaces/IDfInfo.sol";

interface IComptroller {
    function oracle() external view returns (IPriceOracle);
    function getAccountLiquidity(address) external view returns (uint, uint, uint);
}

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

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
interface IUniswapV2Pair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function sync() external;
}

interface IDefiController {
    function defiController() external view returns (address);
}

interface ITokenUSDT {
    function transfer(address to, uint value) external; // USDT don't return bool
}

contract ExtendedLogic is
Initializable,
Adminable,
DSMath
{
    ///////////////////
    // The same state as tokenized deposit
    address public constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address public constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    struct ProfitData {
        uint64 blockNumber;
        uint64 daiProfit; // div 1e12 (6 dec)
        uint64 usdtProfit;
    }

    ProfitData[] public profits;

    IDfDepositToken public token;
    address public dfWallet;

    mapping(address => uint64) public lastProfitDistIndex;

    address usdtExchanger;

    event CompSwap(uint256 timestamp, uint256 compPrice);
    event Profit(address indexed user, uint64 index, uint64 usdtProfit, uint64 daiProfit);

    mapping(address => bool) public approvedContracts; // mapping from old implementation

    // ----------------------------------------------------------------------------------------
    // all vars up to this line are used in Upgradable contract and shouldn't be changed\removed

    address public liquidityProviderAddress;

    // flash loan coefficient (supply: USER_FUNDS * (crate + 100), borrow: USER_FUNDS * crate, flashLoan: USER_FUNDS * crate)
    uint256 public crate;
    mapping(address => uint256) public fundsUnwinded;

    IDfFinanceDeposits public constant dfFinanceDeposits = IDfFinanceDeposits(0xFff9D7b0B6312ead0a1A993BF32f373449006F2F); // mainnet address

    IUniswapV2Router02 constant uniRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // same for kovan and mainnet
    IDfInfo constant dfInfo = IDfInfo(0xee5aEb4314BF8C0A2f0A704305E599343480DbF1); // mainnet address
    address constant bridge = address(0x69c707d975e8d883920003CC357E556a4732CD03); // mainnet address

    IDfDepositToken public tokenETH;
    IDfDepositToken public tokenUSDC;

    uint256 public rewardFee;
    uint256 public ethCoef;
    IDfFinanceDeposits.FlashloanProvider public providerType;
    uint256 public lastFixProfit;
    DfProfits constant dfProfits = DfProfits(0x65D4853d663CeE114A0aA1c946E95479C53e78c2); // contract that contains only profit funds

    event Credit(address token, uint256 amount);
    event SysCredit(uint256 amount);

    uint256 public totalDaiLoanForEth;

    uint256 public aaveFee;

    uint256 public minCRate;

    mapping(uint256 => uint256) ethCoefSnapshoted;

    IDfDepositToken public tokenWBTC;

    uint256 public totalDaiLoanForWBTC;

    uint256 public btcCoef;
    mapping(uint256 => uint256) btcCoefSnapshoted;
    //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    function getFlashLoanAmounts(uint256 amountDAI, uint256 amountWBTC, uint256 amountETH, bool isDeposit) internal returns (uint256 flashLoanDAI, uint256 daiLoanForWBTC, uint256 daiLoanForEth) {
        IPriceOracle compOracle = IComptroller(COMPTROLLER).oracle();
        uint256 _crate = crate;
        uint256 _ethCoef = ethCoef;
        require(_crate > 0 && _ethCoef > 0);
        uint256 _daiPrice = compOracle.price("DAI");
        flashLoanDAI = wmul(amountDAI, _crate);
        if (amountWBTC > 0) {
            if (isDeposit) {               //   8     +       6                 +     6     -  2
                daiLoanForWBTC = wmul(wmul(amountWBTC * compOracle.price("BTC") * _daiPrice / 1e2, btcCoef), (_crate + 1e18)); // 8 + 6 + 6 - 2 = 18
            } else {
                daiLoanForWBTC = wmul(totalDaiLoanForWBTC, amountWBTC * 1e10); // 8+10
            }

            flashLoanDAI += daiLoanForWBTC;
        }
        if (amountETH > 0)  {
            if (isDeposit) {
                daiLoanForEth = wmul(wmul(amountETH * compOracle.price("ETH") * _daiPrice / 1e12, _ethCoef), (_crate + 1e18)); // 18 + 6 + 6 - 12
            } else {
                daiLoanForEth = wmul(totalDaiLoanForEth, amountETH);
            }

            flashLoanDAI += daiLoanForEth;
        }
    }

    // amounts[0] - DAI amounts[1] - WBTC amounts[2] - ETH
    // @return [uint256 avgCRate, uint256 avgEthCoef, uint256 avgBtcCoef, uint256 f, uint256 liquidity]
    function sync(IDfFinanceDeposits.FlashloanProvider _providerType, address flashLoanFromAddress, uint256 _newCRate, uint256 _newEthCoef, uint256 _newBtcCoef, uint256[3] memory amounts, bool check) onlyOwnerOrAdmin public returns (uint256[5] memory ret)  {

        unwindFunds(amounts[0], amounts[1], amounts[2], _providerType, flashLoanFromAddress);

        { // fix "stack too deep"
            IPriceOracle compOracle = IComptroller(COMPTROLLER).oracle();
            uint256 _daiPrice = compOracle.price("DAI") * 1e12;
            uint256 _ethPrice = compOracle.price("ETH") * 1e12;
            uint256 _btcPrice = compOracle.price("BTC") * 1e12;

            uint256 amountTotalETH = tokenETH.totalSupply();
            uint256 amountTotalBTC = tokenWBTC.totalSupply() * 1e10; // calc in 18 dec
            uint256 totalShare = wdiv(amounts[0] + // DAI
                                      wmul(wmul(wmul(amounts[1] * 1e10, btcCoef) , _btcPrice), _daiPrice) + // BTC
                                      wmul(wmul(wmul(amounts[2], ethCoef) , _ethPrice), _daiPrice), // ETH
                // /
                token.totalSupply() + // DAI
                wmul(wmul(wmul(amountTotalBTC, btcCoef), _btcPrice), _daiPrice) + // BTC
                wmul(wmul(wmul(amountTotalETH, ethCoef), _ethPrice), _daiPrice) // ETH
            );
            if (_newCRate > 100) {
                ret[0] = (crate * sub(1e18, totalShare) +  _newCRate * totalShare) / 1e18;
                crate = _newCRate;
            }

            if (_newBtcCoef > 100) {
                uint256 shareBtc = wdiv(amounts[1] * 1e10, amountTotalBTC);
                ret[2] =  (btcCoef * sub(1e18, shareBtc) +  _newBtcCoef * shareBtc) / 1e18;
                btcCoef = _newBtcCoef;
            }

            if (_newEthCoef > 100) {
                uint256 shareEth = wdiv(amounts[2], amountTotalETH);
                ret[1] =  (ethCoef * sub(1e18, shareEth) +  _newEthCoef * shareEth) / 1e18;
                ethCoef = _newEthCoef;
            }
        }

        boostFunds(amounts[0], amounts[1], amounts[2], _providerType, flashLoanFromAddress);

        if (ret[0] > 0) crate = ret[0];
        if (ret[1] > 0) ethCoef = ret[1];
        if (ret[2] > 0) btcCoef = ret[2];

        if (check) {
            (ret[4],,,,ret[3],,,) = dfInfo.getInfo(address(this));
        }
    }

    function unwindFunds(uint256 amountDAI, uint256 amountWBTC, uint256 amountETH, IDfFinanceDeposits.FlashloanProvider _providerType, address flashLoanFromAddress) public onlyOwnerOrAdmin {
        (uint256 flashLoanDAI,,) = getFlashLoanAmounts(amountDAI, amountWBTC, amountETH, false);

        uint256 balanceDAI;
        uint256 balanceWBTC;
        if (amountDAI > 0) balanceDAI = IToken(DAI_ADDRESS).balanceOf(address(this));
        if (amountWBTC > 0) balanceWBTC = IToken(WBTC_ADDRESS).balanceOf(address(this));
        dfFinanceDeposits.withdraw(dfWallet, amountDAI, amountWBTC, amountETH, 0, address(this), flashLoanDAI, 0, _providerType, flashLoanFromAddress);

        if (amountDAI > 0) {
            balanceDAI = sub(IToken(DAI_ADDRESS).balanceOf(address(this)), balanceDAI);
            if (amountDAI > balanceDAI) emit Credit(DAI_ADDRESS, amountDAI - balanceDAI); // system lose via credit
            fundsUnwinded[DAI_ADDRESS] += amountDAI;
        }
        if (amountWBTC > 0) {
            balanceWBTC = sub(IToken(WBTC_ADDRESS).balanceOf(address(this)), balanceWBTC);
            if (amountWBTC > balanceWBTC) emit Credit(WBTC_ADDRESS, amountWBTC - balanceWBTC); // system lose via credit
            fundsUnwinded[WBTC_ADDRESS] += amountWBTC;
        }
        if (amountETH > 0) {
            require(address(this).balance >= amountETH);
            fundsUnwinded[WETH_ADDRESS] += amountETH;
        }

    }

    function boostFunds(uint256 amountDAI, uint256 amountWBTC, uint256 amountETH, IDfFinanceDeposits.FlashloanProvider _providerType, address flashLoanFromAddress) public onlyOwnerOrAdmin  {
        if (amountDAI > fundsUnwinded[DAI_ADDRESS]) amountDAI = fundsUnwinded[DAI_ADDRESS];
        if (amountWBTC > fundsUnwinded[WBTC_ADDRESS]) amountWBTC = fundsUnwinded[WBTC_ADDRESS];
        if (amountETH > fundsUnwinded[WETH_ADDRESS]) amountETH = fundsUnwinded[WETH_ADDRESS];

        uint256 flashLoanDAI;
        uint256 daiLoanForWBTC;
        uint256 daiLoanForEth; // flash loan for 1 ETH
        (flashLoanDAI, daiLoanForWBTC, daiLoanForEth) = getFlashLoanAmounts(amountDAI, amountWBTC, amountETH, true);

        if (amountDAI  > 0)  IToken(DAI_ADDRESS).transfer(address(dfWallet), amountDAI);
        if (amountWBTC > 0)  IToken(WBTC_ADDRESS).transfer(address(dfWallet), amountWBTC);

        dfFinanceDeposits.deposit.value(amountETH)(dfWallet, amountDAI, amountWBTC, 0, flashLoanDAI, 0, _providerType, flashLoanFromAddress);

        if (amountDAI > 0) fundsUnwinded[DAI_ADDRESS] = sub(fundsUnwinded[DAI_ADDRESS], amountDAI);
        if (amountWBTC > 0) fundsUnwinded[WBTC_ADDRESS] = sub(fundsUnwinded[WBTC_ADDRESS], amountWBTC);
        if (amountETH > 0) fundsUnwinded[WETH_ADDRESS] = sub(fundsUnwinded[WETH_ADDRESS], amountETH);

        uint256 totalDETH = sub(tokenETH.totalSupply(), amountETH);
        totalDaiLoanForEth = wdiv(add(wmul(totalDaiLoanForEth, totalDETH), daiLoanForEth), add(totalDETH, amountETH));

        uint256 totalDWBTC = tokenWBTC.totalSupply();
        // = ( totalDaiLoanForWBTC * totalDWBTC + daiLoanForWBTC ) / (totalDWBTC + amounts[1])
        totalDaiLoanForWBTC = wdiv(add(wmul(totalDaiLoanForWBTC/* 18 */, totalDWBTC * 1e10/* 8+10 */), daiLoanForWBTC), add(totalDWBTC, amountWBTC) * 1e10); // convert WBTC to 1e18 (8+10)
    }
}
