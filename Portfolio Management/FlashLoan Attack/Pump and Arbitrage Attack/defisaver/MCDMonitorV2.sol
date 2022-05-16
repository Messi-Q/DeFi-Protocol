pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../interfaces/Manager.sol";
import "../../interfaces/Vat.sol";
import "../../interfaces/Spotter.sol";

import "../../DS/DSMath.sol";
import "../../auth/AdminAuth.sol";
import "../../loggers/DefisaverLogger.sol";
import "../../utils/BotRegistry.sol";
import "../../exchangeV3/DFSExchangeData.sol";

import "./ISubscriptionsV2.sol";
import "./StaticV2.sol";
import "./MCDMonitorProxyV2.sol";

/// @title Implements logic that allows bots to call Boost and Repay
contract MCDMonitorV2 is DSMath, AdminAuth, StaticV2 {
    uint256 public MAX_GAS_PRICE = 800 gwei; // 800 gwei

    uint256 public REPAY_GAS_COST = 1_000_000;
    uint256 public BOOST_GAS_COST = 1_000_000;

    bytes4 public REPAY_SELECTOR = 0xf360ce20; // repayWithLoan(...)
    bytes4 public BOOST_SELECTOR = 0x8ec2ae25; // boostWithLoan(...)

    MCDMonitorProxyV2 public monitorProxyContract = MCDMonitorProxyV2(0x1816A86C4DA59395522a42b871bf11A4E96A1C7a);
    ISubscriptionsV2 public subscriptionsContract = ISubscriptionsV2(0xC45d4f6B6bf41b6EdAA58B01c4298B8d9078269a);
    address public mcdSaverTakerAddress;

    address public constant BOT_REGISTRY_ADDRESS = 0x637726f8b08a7ABE3aE3aCaB01A80E2d8ddeF77B;
    address public constant PROXY_PERMISSION_ADDR = 0x5a4f877CA808Cca3cB7c2A194F80Ab8588FAE26B;

    Manager public manager = Manager(0x5ef30b9986345249bc32d8928B7ee64DE9435E39);
    Vat public vat = Vat(0x35D1b3F3D7966A1DFe207aa4514C12a259A0492B);
    Spotter public spotter = Spotter(0x65C79fcB50Ca1594B025960e539eD7A9a6D434A3);

    DefisaverLogger public constant logger =
        DefisaverLogger(0x5c55B921f590a89C1Ebe84dF170E655a82b62126);

    modifier onlyApproved() {
        require(BotRegistry(BOT_REGISTRY_ADDRESS).botList(msg.sender), "Not auth bot");
        _;
    }

    constructor(
        address _newMcdSaverTakerAddress
    ) public {
        mcdSaverTakerAddress = _newMcdSaverTakerAddress;
    }

    /// @notice Bots call this method to repay for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    function repayFor(
        DFSExchangeData.ExchangeData memory _exchangeData,
        uint256 _cdpId,
        uint256 _nextPrice,
        address _joinAddr
    ) public payable onlyApproved {
        bool isAllowed;
        uint256 ratioBefore;
        string memory errReason;

        (isAllowed, ratioBefore, errReason) = checkPreconditions(
            Method.Repay,
            _cdpId,
            _nextPrice
        );
        require(isAllowed, errReason);

        uint256 gasCost = calcGasCost(REPAY_GAS_COST);

        address usersProxy = subscriptionsContract.getOwner(_cdpId);

        monitorProxyContract.callExecute{value: msg.value}(
            usersProxy,
            mcdSaverTakerAddress,
            abi.encodeWithSelector(REPAY_SELECTOR, _exchangeData, _cdpId, gasCost, _joinAddr, 0)
        );

        bool isGoodRatio;
        uint256 ratioAfter;

        (isGoodRatio, ratioAfter, errReason) = ratioGoodAfter(
            Method.Repay,
            _cdpId,
            _nextPrice,
            ratioBefore
        );
        require(isGoodRatio, errReason);

        returnEth();

        logger.Log(
            address(this),
            usersProxy,
            "AutomaticMCDRepay",
            abi.encode(ratioBefore, ratioAfter)
        );
    }

    /// @notice Bots call this method to boost for user when conditions are met
    /// @dev If the contract ownes gas token it will try and use it for gas price reduction
    function boostFor(
        DFSExchangeData.ExchangeData memory _exchangeData,
        uint256 _cdpId,
        uint256 _nextPrice,
        address _joinAddr
    ) public payable onlyApproved {
        bool isAllowed;
        uint256 ratioBefore;
        string memory errReason;

        (isAllowed, ratioBefore, errReason) = checkPreconditions(
            Method.Boost,
            _cdpId,
            _nextPrice
        );
        require(isAllowed, errReason);

        uint256 gasCost = calcGasCost(BOOST_GAS_COST);

        address usersProxy = subscriptionsContract.getOwner(_cdpId);

        monitorProxyContract.callExecute{value: msg.value}(
            usersProxy,
            mcdSaverTakerAddress,
            abi.encodeWithSelector(BOOST_SELECTOR, _exchangeData, _cdpId, gasCost, _joinAddr, 0)
        );

        bool isGoodRatio;
        uint256 ratioAfter;

        (isGoodRatio, ratioAfter, errReason) = ratioGoodAfter(
            Method.Boost,
            _cdpId,
            _nextPrice,
            ratioBefore
        );
        require(isGoodRatio, errReason);

        returnEth();

        logger.Log(
            address(this),
            usersProxy,
            "AutomaticMCDBoost",
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

    /// @notice Returns an address that owns the CDP
    /// @param _cdpId Id of the CDP
    function getOwner(uint256 _cdpId) public view returns (address) {
        return manager.owns(_cdpId);
    }

    /// @notice Gets CDP info (collateral, debt)
    /// @param _cdpId Id of the CDP
    /// @param _ilk Ilk of the CDP
    function getCdpInfo(uint256 _cdpId, bytes32 _ilk) public view returns (uint256, uint256) {
        address urn = manager.urns(_cdpId);

        (uint256 collateral, uint256 debt) = vat.urns(_ilk, urn);
        (, uint256 rate, , , ) = vat.ilks(_ilk);

        return (collateral, rmul(debt, rate));
    }

    /// @notice Gets a price of the asset
    /// @param _ilk Ilk of the CDP
    function getPrice(bytes32 _ilk) public view returns (uint256) {
        (, uint256 mat) = spotter.ilks(_ilk);
        (, , uint256 spot, , ) = vat.ilks(_ilk);

        return rmul(rmul(spot, spotter.par()), mat);
    }

    /// @notice Gets CDP ratio
    /// @param _cdpId Id of the CDP
    /// @param _nextPrice Next price for user
    function getRatio(uint256 _cdpId, uint256 _nextPrice) public view returns (uint256) {
        bytes32 ilk = manager.ilks(_cdpId);
        uint256 price = (_nextPrice == 0) ? getPrice(ilk) : _nextPrice;

        (uint256 collateral, uint256 debt) = getCdpInfo(_cdpId, ilk);

        if (debt == 0) return 0;

        return rdiv(wmul(collateral, price), debt) / (10**18);
    }

    /// @notice Checks if Boost/Repay could be triggered for the CDP
    /// @dev Called by MCDMonitor to enforce the min/max check
    function checkPreconditions(
        Method _method,
        uint256 _cdpId,
        uint256 _nextPrice
    )
        public
        view
        returns (
            bool,
            uint256,
            string memory
        )
    {

        (bool subscribed, CdpHolder memory holder) = subscriptionsContract.getCdpHolder(_cdpId);

        // check if cdp is subscribed
        if (!subscribed) return (false, 0, "Cdp not sub");

        // check if using next price is allowed
        if (_nextPrice > 0 && !holder.nextPriceEnabled)
            return (false, 0, "Next price send but not enabled");

        // check if boost and boost allowed
        if (_method == Method.Boost && !holder.boostEnabled)
            return (false, 0, "Boost not enabled");

        // check if owner is still owner
        if (getOwner(_cdpId) != holder.owner) return (false, 0, "EOA not subbed owner");

        uint256 currRatio = getRatio(_cdpId, _nextPrice);

        if (_method == Method.Repay) {
            if (currRatio > holder.minRatio) return (false, 0, "Ratio is bigger than min");
        } else if (_method == Method.Boost) {
            if (currRatio < holder.maxRatio) return (false, 0, "Ratio is less than max");
        }

        return (true, currRatio, "");
    }

    /// @dev After the Boost/Repay check if the ratio doesn't trigger another call
    function ratioGoodAfter(
        Method _method,
        uint256 _cdpId,
        uint256 _nextPrice,
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

        (, CdpHolder memory holder) = subscriptionsContract.getCdpHolder(_cdpId);
        uint256 currRatio = getRatio(_cdpId, _nextPrice);

        if (_method == Method.Repay) {
            if (currRatio >= holder.maxRatio)
                return (false, currRatio, "Repay increased ratio over max");
            if (currRatio <= _beforeRatio) return (false, currRatio, "Repay made ratio worse");
        } else if (_method == Method.Boost) {
            if (currRatio <= holder.minRatio)
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

    /// @notice Allows owner to change max gas price
    /// @param _maxGasPrice New max gas price
    function changeMaxGasPrice(uint256 _maxGasPrice) public onlyOwner {
        require(_maxGasPrice < 2000 gwei, "Max gas price over the limit");

        MAX_GAS_PRICE = _maxGasPrice;
    }
}
