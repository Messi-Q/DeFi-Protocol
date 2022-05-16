pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../DS/DSMath.sol";
import "../../auth/AdminAuth.sol";
import "../../loggers/DefisaverLogger.sol";
import "../../exchangeV3/DFSExchangeData.sol";
import "./AaveMonitorProxyV2.sol";
import "./AaveSubscriptionsV2.sol";
import "../AaveSafetyRatioV2.sol";

/// @title Contract implements logic of calling boost/repay in the automatic system
contract AaveMonitorV2 is AdminAuth, DSMath, AaveSafetyRatioV2 {

    using SafeERC20 for ERC20;

    enum Method { Boost, Repay }

    uint public MAX_GAS_PRICE = 800 gwei;

    uint public REPAY_GAS_COST = 1_500_000;
    uint public BOOST_GAS_COST = 1_700_000;

    address public constant DEFISAVER_LOGGER = 0x5c55B921f590a89C1Ebe84dF170E655a82b62126;
    address public constant AAVE_MARKET_ADDRESS = 0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5;

    AaveMonitorProxyV2 public aaveMonitorProxy = AaveMonitorProxyV2(0x380982902872836ceC629171DaeAF42EcC02226e);
    AaveSubscriptionsV2 public subscriptionsContract = AaveSubscriptionsV2(0x6B25043BF08182d8e86056C6548847aF607cd7CD);
    address public aaveSaverProxy;

    DefisaverLogger public logger = DefisaverLogger(DEFISAVER_LOGGER);

    modifier onlyApproved() {
        require(BotRegistry(BOT_REGISTRY_ADDRESS).botList(msg.sender), "Not auth bot");
        _;
    }

    /// @param _newAaveSaverProxy Address of the AaveV2 saver contract
    constructor(address _newAaveSaverProxy) public {
        aaveSaverProxy = _newAaveSaverProxy;
    }

    /// @notice Bots call this method to repay for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    /// @param _exData Exchange data
    /// @param _user The actual address that owns the Aave position
    function repayFor(
        DFSExchangeData.ExchangeData memory _exData,
        address _user,
        uint256 _rateMode,
        uint256 _flAmount
    ) public payable onlyApproved {
        string memory errReason;
        bool isAllowed;
        uint256 ratioBefore;

        AaveSubscriptionsV2.AaveHolder memory holder = subscriptionsContract.getHolder(_user);

        (isAllowed, ratioBefore, errReason) = checkPreconditions(holder, Method.Repay, _user);
        require(isAllowed, errReason); // check if conditions are met

        uint256 gasCost = calcGasCost(REPAY_GAS_COST);

        aaveMonitorProxy.callExecute{value: msg.value}(
            _user,
            aaveSaverProxy,
            abi.encodeWithSignature(
                "repay(address,(address,address,uint256,uint256,uint256,uint256,address,address,bytes,(address,address,address,uint256,uint256,bytes)),uint256,uint256,uint256)",
                AAVE_MARKET_ADDRESS,
                _exData,
                _rateMode,
                gasCost,
                _flAmount
            )
        );

        bool isGoodRatio;
        uint256 ratioAfter;

        (isGoodRatio, ratioAfter, errReason) = ratioGoodAfter(holder, Method.Repay, _user, ratioBefore);
        require(isGoodRatio, errReason); // check if the after result of the actions is good

        returnEth();

        logger.Log(address(this), _user, "AutomaticAaveRepayV2", abi.encode(ratioBefore, ratioAfter));
    }

    /// @notice Bots call this method to boost for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    /// @param _exData Exchange data
    /// @param _user The actual address that owns the Aave position
    function boostFor(
        DFSExchangeData.ExchangeData memory _exData,
        address _user,
        uint256 _rateMode,
        uint256 _flAmount
    ) public payable onlyApproved {
        string memory errReason;
        bool isAllowed;
        uint256 ratioBefore;

        AaveSubscriptionsV2.AaveHolder memory holder = subscriptionsContract.getHolder(_user);

        (isAllowed, ratioBefore, errReason) = checkPreconditions(holder, Method.Boost, _user);
        require(isAllowed, errReason); // check if conditions are met

        uint256 gasCost = calcGasCost(BOOST_GAS_COST);

        aaveMonitorProxy.callExecute{value: msg.value}(
            _user,
            aaveSaverProxy,
            abi.encodeWithSignature(
                "boost(address,(address,address,uint256,uint256,uint256,uint256,address,address,bytes,(address,address,address,uint256,uint256,bytes)),uint256,uint256,uint256)",
                AAVE_MARKET_ADDRESS,
                _exData,
                _rateMode,
                gasCost,
                _flAmount
            )
        );

        bool isGoodRatio;
        uint256 ratioAfter;

        (isGoodRatio, ratioAfter, errReason) = ratioGoodAfter(holder, Method.Boost, _user, ratioBefore);
        require(isGoodRatio, errReason);  // check if the after result of the actions is good

        returnEth();

        logger.Log(address(this), _user, "AutomaticAaveBoostV2", abi.encode(ratioBefore, ratioAfter));
    }

/******************* INTERNAL METHODS ********************************/
    function returnEth() internal {
        // return if some eth left
        if (address(this).balance > 0) {
            msg.sender.transfer(address(this).balance);
        }
    }

/******************* STATIC METHODS ********************************/

    /// @notice Checks if Boost/Repay could be triggered for the CDP
    /// @dev Called by AaveMonitor to enforce the min/max check
    /// @param _method Type of action to be called
    /// @param _user The actual address that owns the Aave position
    function checkPreconditions(AaveSubscriptionsV2.AaveHolder memory _holder, Method _method, address _user) public view returns(bool, uint, string memory) {
        bool subscribed = subscriptionsContract.isSubscribed(_user);

        // check if cdp is subscribed
        if (!subscribed) return (false, 0, "User not subbed");

        // check if boost and boost allowed
        if (_method == Method.Boost && !_holder.boostEnabled) return (false, 0, "Boost not enabled");

        uint currRatio = getSafetyRatio(AAVE_MARKET_ADDRESS, _user);

        if (_method == Method.Repay) {
            if (currRatio > _holder.minRatio) return (false, 0, "Ratio not under min");
        } else if (_method == Method.Boost) {
            if (currRatio < _holder.maxRatio) return (false, 0, "Ratio not over max");
        }

        return (true, currRatio, "");
    }

    /// @dev After the Boost/Repay check if the ratio doesn't trigger another call
    /// @param _method Type of action to be called
    /// @param _user The actual address that owns the Aave position
    /// @param _ratioBefore Ratio before action
    /// @return Boolean if the recent action preformed correctly and the ratio
    function ratioGoodAfter(AaveSubscriptionsV2.AaveHolder memory _holder, Method _method, address _user, uint _ratioBefore) public view returns(bool, uint, string memory) {

        uint currRatio = getSafetyRatio(AAVE_MARKET_ADDRESS, _user);

        if (_method == Method.Repay) {
            if (currRatio >= _holder.maxRatio)
                return (false, currRatio, "Repay increased ratio over max");
            if (currRatio <= _ratioBefore) return (false, currRatio, "Repay made ratio worse");
        } else if (_method == Method.Boost) {
            if (currRatio <= _holder.minRatio)
                return (false, currRatio, "Boost lowered ratio over min");
            if (currRatio >= _ratioBefore) return (false, currRatio, "Boost didn't lower ratio");
        }

        return (true, currRatio, "");
    }

    /// @notice Calculates gas cost (in Eth) of tx
    /// @dev Gas price is limited to MAX_GAS_PRICE to prevent attack of draining user CDP
    /// @param _gasAmount Amount of gas used for the tx
    function calcGasCost(uint _gasAmount) public view returns (uint) {
        uint gasPrice = tx.gasprice <= MAX_GAS_PRICE ? tx.gasprice : MAX_GAS_PRICE;

        return mul(gasPrice, _gasAmount);
    }

/******************* OWNER ONLY OPERATIONS ********************************/

    /// @notice Allows owner to change gas cost for boost operation, but only up to 3 millions
    /// @param _gasCost New gas cost for boost method
    function changeBoostGasCost(uint _gasCost) public onlyOwner {
        require(_gasCost < 3_000_000, "Boost gas cost over limit");

        BOOST_GAS_COST = _gasCost;
    }

    /// @notice Allows owner to change gas cost for repay operation, but only up to 3 millions
    /// @param _gasCost New gas cost for repay method
    function changeRepayGasCost(uint _gasCost) public onlyOwner {
        require(_gasCost < 3_000_000, "Repay gas cost over limit");

        REPAY_GAS_COST = _gasCost;
    }

    /// @notice Owner can change the maximum the contract can take for gas price
    /// @param _maxGasPrice New Max gas price
    function changeMaxGasPrice(uint256 _maxGasPrice) public onlyOwner {
        require(_maxGasPrice < 2000 gwei, "Max gas price over the limit");

        MAX_GAS_PRICE = _maxGasPrice;
    }
}
