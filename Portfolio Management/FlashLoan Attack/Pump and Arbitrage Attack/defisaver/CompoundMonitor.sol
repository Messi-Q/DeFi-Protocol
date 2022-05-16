pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../utils/BotRegistry.sol";
import "./CompoundMonitorProxy.sol";
import "./CompoundSubscriptions.sol";
import "../../DS/DSMath.sol";
import "../../auth/AdminAuth.sol";
import "../../loggers/DefisaverLogger.sol";
import "../CompoundSafetyRatio.sol";
import "../../exchangeV3/DFSExchangeData.sol";

/// @title Contract implements logic of calling boost/repay in the automatic system
contract CompoundMonitor is AdminAuth, DSMath, CompoundSafetyRatio {
    using SafeERC20 for ERC20;

    enum Method {
        Boost,
        Repay
    }

    uint256 public MAX_GAS_PRICE = 800 gwei;

    uint256 public REPAY_GAS_COST = 1_500_000;
    uint256 public BOOST_GAS_COST = 1_000_000;

    address public constant DEFISAVER_LOGGER = 0x5c55B921f590a89C1Ebe84dF170E655a82b62126;
    address public constant BOT_REGISTRY_ADDRESS = 0x637726f8b08a7ABE3aE3aCaB01A80E2d8ddeF77B;

    CompoundMonitorProxy public compoundMonitorProxy = CompoundMonitorProxy(0xB1cF8DE8e791E4Ed1Bd86c03E2fc1f14389Cb10a);
    CompoundSubscriptions public subscriptionsContract = CompoundSubscriptions(0x52015EFFD577E08f498a0CCc11905925D58D6207);
    address public compoundFlashLoanTakerAddress;

    DefisaverLogger public logger = DefisaverLogger(DEFISAVER_LOGGER);

    modifier onlyApproved() {
        require(BotRegistry(BOT_REGISTRY_ADDRESS).botList(msg.sender), "Not auth bot");
        _;
    }

    /// @param _newCompoundFlashLoanTaker Contract that actually performs Repay/Boost
    constructor(
        address _newCompoundFlashLoanTaker
    ) public {
        compoundFlashLoanTakerAddress = _newCompoundFlashLoanTaker;
    }

    /// @notice Bots call this method to repay for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    /// @param _exData Exchange data
    /// @param _cAddresses cTokens addreses and exchange [cCollAddress, cBorrowAddress, exchangeAddress]
    /// @param _user The actual address that owns the Compound position
    function repayFor(
        DFSExchangeData.ExchangeData memory _exData,
        address[2] memory _cAddresses, // cCollAddress, cBorrowAddress
        address _user
    ) public payable onlyApproved {
        bool isAllowed;
        uint256 ratioBefore;
        string memory errReason;

        CompoundSubscriptions.CompoundHolder memory holder = subscriptionsContract.getHolder(_user);

        (isAllowed, ratioBefore, errReason) = checkPreconditions(holder, Method.Repay, _user);
        require(isAllowed, errReason); // check if conditions are met

        uint256 gasCost = calcGasCost(REPAY_GAS_COST);

        compoundMonitorProxy.callExecute{value: msg.value}(
            _user,
            compoundFlashLoanTakerAddress,
            abi.encodeWithSignature(
                "repayWithLoan((address,address,uint256,uint256,uint256,uint256,address,address,bytes,(address,address,address,uint256,uint256,bytes)),address[2],uint256)",
                _exData,
                _cAddresses,
                gasCost
            )
        );

        bool isGoodRatio;
        uint256 ratioAfter;

        (isGoodRatio, ratioAfter, errReason) = ratioGoodAfter(
            holder,
            Method.Repay,
            _user,
            ratioBefore
        );
        require(isGoodRatio, errReason); // check if the after result of the actions is good

        returnEth();

        logger.Log(
            address(this),
            _user,
            "AutomaticCompoundRepay",
            abi.encode(ratioBefore, ratioAfter)
        );
    }

    /// @notice Bots call this method to boost for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    /// @param _exData Exchange data
    /// @param _cAddresses cTokens addreses and exchange [cCollAddress, cBorrowAddress, exchangeAddress]
    /// @param _user The actual address that owns the Compound position
    function boostFor(
        DFSExchangeData.ExchangeData memory _exData,
        address[2] memory _cAddresses, // cCollAddress, cBorrowAddress
        address _user
    ) public payable onlyApproved {
        string memory errReason;
        bool isAllowed;
        uint256 ratioBefore;

        CompoundSubscriptions.CompoundHolder memory holder = subscriptionsContract.getHolder(_user);

        (isAllowed, ratioBefore, errReason) = checkPreconditions(holder, Method.Boost, _user);
        require(isAllowed, errReason); // check if conditions are met

        uint256 gasCost = calcGasCost(BOOST_GAS_COST);

        compoundMonitorProxy.callExecute{value: msg.value}(
            _user,
            compoundFlashLoanTakerAddress,
            abi.encodeWithSignature(
                "boostWithLoan((address,address,uint256,uint256,uint256,uint256,address,address,bytes,(address,address,address,uint256,uint256,bytes)),address[2],uint256)",
                _exData,
                _cAddresses,
                gasCost
            )
        );

        bool isGoodRatio;
        uint256 ratioAfter;

        (isGoodRatio, ratioAfter, errReason) = ratioGoodAfter(
            holder,
            Method.Boost,
            _user,
            ratioBefore
        );
        require(isGoodRatio, errReason); // check if the after result of the actions is good

        returnEth();

        logger.Log(
            address(this),
            _user,
            "AutomaticCompoundBoost",
            abi.encode(ratioBefore, ratioAfter)
        );
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
    /// @dev Called by MCDMonitor to enforce the min/max check
    /// @param _method Type of action to be called
    /// @param _user The actual address that owns the Compound position
    /// @return Boolean if it can be called and the ratio
    function checkPreconditions(
        CompoundSubscriptions.CompoundHolder memory _holder,
        Method _method,
        address _user
    )
        public
        view
        returns (
            bool,
            uint256,
            string memory
        )
    {
        bool subscribed = subscriptionsContract.isSubscribed(_user);

        // check if user is subscribed
        if (!subscribed) return (false, 0, "User not subbed");

        // check if boost and boost allowed
        if (_method == Method.Boost && !_holder.boostEnabled)
            return (false, 0, "Boost not enabled");

        uint256 currRatio = getSafetyRatio(_user);

        if (_method == Method.Repay) {
            if (currRatio > _holder.minRatio) return (false, 0, "Ratio not under min");
        } else if (_method == Method.Boost) {
            if (currRatio < _holder.maxRatio) return (false, 0, "Ratio not over max");
        }

        return (true, currRatio, "");
    }

    /// @dev After the Boost/Repay check if the ratio doesn't trigger another call
    /// @param _method Type of action to be called
    /// @param _user The actual address that owns the Compound position
    /// @param _beforeRatio Ratio before boost
    /// @return Boolean if the recent action preformed correctly and the ratio
    function ratioGoodAfter(
        CompoundSubscriptions.CompoundHolder memory _holder,
        Method _method,
        address _user,
        uint256 _beforeRatio
    )
        public
        view
        returns (
            bool,
            uint256,
            string memory
        )
    {
        uint256 currRatio = getSafetyRatio(_user);

        if (_method == Method.Repay) {
            if (currRatio >= _holder.maxRatio)
                return (false, currRatio, "Repay increased ratio over max");
            if (currRatio <= _beforeRatio) return (false, currRatio, "Repay made ratio worse");
        } else if (_method == Method.Boost) {
            if (currRatio <= _holder.minRatio)
                return (false, currRatio, "Boost lowered ratio over min");
            if (currRatio >= _beforeRatio) return (false, currRatio, "Boost didn't lower ratio");
        }

        return (true, currRatio, "");
    }

    /// @notice Calculates gas cost (in Eth) of tx
    /// @dev Gas price is limited to MAX_GAS_PRICE to prevent attack of draining user CDP
    /// @param _gasAmount Amount of gas used for the tx
    function calcGasCost(uint256 _gasAmount) public view returns (uint256) {
        uint256 gasPrice = tx.gasprice <= MAX_GAS_PRICE ? tx.gasprice : MAX_GAS_PRICE;

        return mul(gasPrice, _gasAmount);
    }

    /******************* OWNER ONLY OPERATIONS ********************************/

    /// @notice Allows owner to change gas cost for boost operation, but only up to 3 millions
    /// @param _gasCost New gas cost for boost method
    function changeBoostGasCost(uint256 _gasCost) public onlyOwner {
        require(_gasCost < 3_000_000, "Boost gas cost over limit");

        BOOST_GAS_COST = _gasCost;
    }

    /// @notice Allows owner to change gas cost for repay operation, but only up to 3 millions
    /// @param _gasCost New gas cost for repay method
    function changeRepayGasCost(uint256 _gasCost) public onlyOwner {
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
