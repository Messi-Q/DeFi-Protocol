// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";

import "./ConverterVersion.sol";

import "./interfaces/IConverter.sol";
import "./interfaces/IConverterAnchor.sol";
import "./interfaces/IConverterUpgrader.sol";
import "./interfaces/IBancorFormula.sol";

import "../utility/ContractRegistryClient.sol";
import "../utility/ReentrancyGuard.sol";
import "../utility/interfaces/IWhitelist.sol";

import "../token/ReserveToken.sol";

/**
 * @dev This contract contains the main logic for conversions between different ERC20 tokens.
 *
 * It is also the upgradable part of the mechanism (note that upgrades are opt-in).
 *
 * The anchor must be set on construction and cannot be changed afterwards.
 * Wrappers are provided for some of the anchor's functions, for easier access.
 *
 * Once the converter accepts ownership of the anchor, it becomes the anchor's sole controller
 * and can execute any of its functions.
 *
 * To upgrade the converter, anchor ownership must be transferred to a new converter, along with
 * any relevant data.
 *
 * Note that the converter can transfer anchor ownership to a new converter that
 * doesn't allow upgrades anymore, for finalizing the relationship between the converter
 * and the anchor.
 *
 * Converter types (defined as uint16 type) -
 * 0 = liquid token converter (deprecated)
 * 1 = liquidity pool v1 converter
 * 2 = liquidity pool v2 converter (deprecated)
 *
 * Note that converters don't currently support tokens with transfer fees.
 */
abstract contract ConverterBase is ConverterVersion, IConverter, ContractRegistryClient, ReentrancyGuard {
    using SafeMath for uint256;
    using ReserveToken for IReserveToken;

    struct Reserve {
        uint256 balance; // reserve balance
        uint32 weight; // reserve weight, represented in ppm, 1-1000000
        bool deprecated1; // deprecated
        bool deprecated2; // deprecated
        bool isSet; // true if the reserve is valid, false otherwise
    }

    IConverterAnchor public override anchor; // converter anchor contract
    IWhitelist public conversionWhitelist; // whitelist contract with list of addresses that are allowed to use the converter
    IReserveToken[] public reserveTokens; // reserve token addresses (prior version 17, use 'connectorTokens' instead)
    mapping(IReserveToken => Reserve) public reserves; // reserve token addresses -> reserve data (prior version 17, use 'connectors' instead)
    uint32 public reserveRatio = 0; // ratio between the reserves and the market cap, equal to the total reserve weights
    uint32 public override maxConversionFee = 0; // maximum conversion fee for the lifetime of the contract,
    // represented in ppm, 0...1000000 (0 = no fee, 100 = 0.01%, 1000000 = 100%)
    uint32 public override conversionFee = 0; // current conversion fee, represented in ppm, 0...maxConversionFee

    /**
     * @dev used by sub-contracts to initialize a new converter
     *
     * @param  _anchor             anchor governed by the converter
     * @param  _registry           address of a contract registry contract
     * @param  _maxConversionFee   maximum conversion fee, represented in ppm
     */
    constructor(
        IConverterAnchor _anchor,
        IContractRegistry _registry,
        uint32 _maxConversionFee
    ) internal ContractRegistryClient(_registry) validAddress(address(_anchor)) validConversionFee(_maxConversionFee) {
        anchor = _anchor;
        maxConversionFee = _maxConversionFee;
    }

    // ensures that the converter is active
    modifier active() {
        _active();
        _;
    }

    // error message binary size optimization
    function _active() internal view {
        require(isActive(), "ERR_INACTIVE");
    }

    // ensures that the converter is not active
    modifier inactive() {
        _inactive();
        _;
    }

    // error message binary size optimization
    function _inactive() internal view {
        require(!isActive(), "ERR_ACTIVE");
    }

    // validates a reserve token address - verifies that the address belongs to one of the reserve tokens
    modifier validReserve(IReserveToken _address) {
        _validReserve(_address);
        _;
    }

    // error message binary size optimization
    function _validReserve(IReserveToken _address) internal view {
        require(reserves[_address].isSet, "ERR_INVALID_RESERVE");
    }

    // validates conversion fee
    modifier validConversionFee(uint32 _conversionFee) {
        _validConversionFee(_conversionFee);
        _;
    }

    // error message binary size optimization
    function _validConversionFee(uint32 _conversionFee) internal pure {
        require(_conversionFee <= PPM_RESOLUTION, "ERR_INVALID_CONVERSION_FEE");
    }

    // validates reserve weight
    modifier validReserveWeight(uint32 _weight) {
        _validReserveWeight(_weight);
        _;
    }

    // error message binary size optimization
    function _validReserveWeight(uint32 _weight) internal pure {
        require(_weight > 0 && _weight <= PPM_RESOLUTION, "ERR_INVALID_RESERVE_WEIGHT");
    }

    // overrides interface declaration
    function converterType() public pure virtual override returns (uint16);

    // overrides interface declaration
    function targetAmountAndFee(
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        uint256 _amount
    ) public view virtual override returns (uint256, uint256);

    /**
     * @dev deposits ether
     * can only be called if the converter has an ETH reserve
     */
    receive() external payable override(IConverter) validReserve(ReserveToken.NATIVE_TOKEN_ADDRESS) {}

    /**
     * @dev checks whether or not the converter version is 28 or higher
     *
     * @return true, since the converter version is 28 or higher
     */
    function isV28OrHigher() public pure returns (bool) {
        return true;
    }

    /**
     * @dev allows the owner to update & enable the conversion whitelist contract address
     * when set, only addresses that are whitelisted are actually allowed to use the converter
     * note that the whitelist check is actually done by the BancorNetwork contract
     *
     * @param _whitelist    address of a whitelist contract
     */
    function setConversionWhitelist(IWhitelist _whitelist) public ownerOnly {
        conversionWhitelist = _whitelist;
    }

    /**
     * @dev returns true if the converter is active, false otherwise
     *
     * @return true if the converter is active, false otherwise
     */
    function isActive() public view virtual override returns (bool) {
        return anchor.owner() == address(this);
    }

    /**
     * @dev transfers the anchor ownership
     * the new owner needs to accept the transfer
     * can only be called by the converter upgrader while the upgrader is the owner
     * note that prior to version 28, you should use 'transferAnchorOwnership' instead
     *
     * @param _newOwner    new token owner
     */
    function transferAnchorOwnership(address _newOwner) public override ownerOnly only(CONVERTER_UPGRADER) {
        anchor.transferOwnership(_newOwner);
    }

    /**
     * @dev accepts ownership of the anchor after an ownership transfer
     * most converters are also activated as soon as they accept the anchor ownership
     * can only be called by the contract owner
     * note that prior to version 28, you should use 'acceptTokenOwnership' instead
     */
    function acceptAnchorOwnership() public virtual override ownerOnly {
        // verify the the converter has at least one reserve
        require(reserveTokenCount() > 0, "ERR_INVALID_RESERVE_COUNT");
        anchor.acceptOwnership();
        syncReserveBalances();
    }

    /**
     * @dev updates the current conversion fee
     * can only be called by the contract owner
     *
     * @param _conversionFee new conversion fee, represented in ppm
     */
    function setConversionFee(uint32 _conversionFee) public override ownerOnly {
        require(_conversionFee <= maxConversionFee, "ERR_INVALID_CONVERSION_FEE");
        emit ConversionFeeUpdate(conversionFee, _conversionFee);
        conversionFee = _conversionFee;
    }

    /**
     * @dev transfers reserve balances to a new converter during an upgrade
     * can only be called by the converter upgraded which should be set at its owner
     *
     * @param _newConverter address of the converter to receive the new amount
     */
    function transferReservesOnUpgrade(address _newConverter)
        external
        override
        protected
        ownerOnly
        only(CONVERTER_UPGRADER)
    {
        uint256 reserveCount = reserveTokens.length;
        for (uint256 i = 0; i < reserveCount; ++i) {
            IReserveToken reserveToken = reserveTokens[i];

            reserveToken.safeTransfer(_newConverter, reserveToken.balanceOf(address(this)));

            syncReserveBalance(reserveToken);
        }
    }

    /**
     * @dev upgrades the converter to the latest version
     * can only be called by the owner
     * note that the owner needs to call acceptOwnership on the new converter after the upgrade
     */
    function upgrade() public ownerOnly {
        IConverterUpgrader converterUpgrader = IConverterUpgrader(addressOf(CONVERTER_UPGRADER));

        // trigger de-activation event
        emit Activation(converterType(), anchor, false);

        transferOwnership(address(converterUpgrader));
        converterUpgrader.upgrade(version);
        acceptOwnership();
    }

    /**
     * @dev executed by the upgrader at the end of the upgrade process to handle custom pool logic
     */
    function onUpgradeComplete() external override protected ownerOnly only(CONVERTER_UPGRADER) {}

    /**
     * @dev returns the number of reserve tokens
     * note that prior to version 17, you should use 'connectorTokenCount' instead
     *
     * @return number of reserve tokens
     */
    function reserveTokenCount() public view returns (uint16) {
        return uint16(reserveTokens.length);
    }

    /**
     * @dev defines a new reserve token for the converter
     * can only be called by the owner while the converter is inactive
     *
     * @param _token   address of the reserve token
     * @param _weight  reserve weight, represented in ppm, 1-1000000
     */
    function addReserve(IReserveToken _token, uint32 _weight)
        public
        virtual
        override
        ownerOnly
        inactive
        validExternalAddress(address(_token))
        validReserveWeight(_weight)
    {
        // validate input
        require(address(_token) != address(anchor) && !reserves[_token].isSet, "ERR_INVALID_RESERVE");
        require(_weight <= PPM_RESOLUTION - reserveRatio, "ERR_INVALID_RESERVE_WEIGHT");
        require(reserveTokenCount() < uint16(-1), "ERR_INVALID_RESERVE_COUNT");

        Reserve storage newReserve = reserves[_token];
        newReserve.balance = 0;
        newReserve.weight = _weight;
        newReserve.isSet = true;
        reserveTokens.push(_token);
        reserveRatio += _weight;
    }

    /**
     * @dev returns the reserve's weight
     * added in version 28
     *
     * @param _reserveToken    reserve token contract address
     *
     * @return reserve weight
     */
    function reserveWeight(IReserveToken _reserveToken) public view validReserve(_reserveToken) returns (uint32) {
        return reserves[_reserveToken].weight;
    }

    /**
     * @dev returns the reserve's balance
     * note that prior to version 17, you should use 'getConnectorBalance' instead
     *
     * @param _reserveToken    reserve token contract address
     *
     * @return reserve balance
     */
    function reserveBalance(IReserveToken _reserveToken)
        public
        view
        override
        validReserve(_reserveToken)
        returns (uint256)
    {
        return reserves[_reserveToken].balance;
    }

    /**
     * @dev converts a specific amount of source tokens to target tokens
     * can only be called by the bancor network contract
     *
     * @param _sourceToken source reserve token
     * @param _targetToken target reserve token
     * @param _amount      amount of tokens to convert (in units of the source token)
     * @param _trader      address of the caller who executed the conversion
     * @param _beneficiary wallet to receive the conversion result
     *
     * @return amount of tokens received (in units of the target token)
     */
    function convert(
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        uint256 _amount,
        address _trader,
        address payable _beneficiary
    ) public payable override protected only(BANCOR_NETWORK) returns (uint256) {
        // validate input
        require(_sourceToken != _targetToken, "ERR_SAME_SOURCE_TARGET");

        // if a whitelist is set, verify that both and trader and the beneficiary are whitelisted
        require(
            address(conversionWhitelist) == address(0) ||
                (conversionWhitelist.isWhitelisted(_trader) && conversionWhitelist.isWhitelisted(_beneficiary)),
            "ERR_NOT_WHITELISTED"
        );

        return doConvert(_sourceToken, _targetToken, _amount, _trader, _beneficiary);
    }

    /**
     * @dev converts a specific amount of source tokens to target tokens
     * called by ConverterBase and allows the inherited contracts to implement custom conversion logic
     *
     * @param _sourceToken source reserve token
     * @param _targetToken target reserve token
     * @param _amount      amount of tokens to convert (in units of the source token)
     * @param _trader      address of the caller who executed the conversion
     * @param _beneficiary wallet to receive the conversion result
     *
     * @return amount of tokens received (in units of the target token)
     */
    function doConvert(
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        uint256 _amount,
        address _trader,
        address payable _beneficiary
    ) internal virtual returns (uint256);

    /**
     * @dev returns the conversion fee for a given target amount
     *
     * @param _targetAmount  target amount
     *
     * @return conversion fee
     */
    function calculateFee(uint256 _targetAmount) internal view returns (uint256) {
        return _targetAmount.mul(conversionFee) / PPM_RESOLUTION;
    }

    /**
     * @dev syncs the stored reserve balance for a given reserve with the real reserve balance
     *
     * @param _reserveToken    address of the reserve token
     */
    function syncReserveBalance(IReserveToken _reserveToken) internal validReserve(_reserveToken) {
        reserves[_reserveToken].balance = _reserveToken.balanceOf(address(this));
    }

    /**
     * @dev syncs all stored reserve balances
     */
    function syncReserveBalances() internal {
        uint256 reserveCount = reserveTokens.length;
        for (uint256 i = 0; i < reserveCount; i++) {
            syncReserveBalance(reserveTokens[i]);
        }
    }

    /**
     * @dev helper, dispatches the Conversion event
     *
     * @param _sourceToken     source reserve token
     * @param _targetToken     target reserve token
     * @param _trader          address of the caller who executed the conversion
     * @param _amount          amount purchased/sold (in the source token)
     * @param _returnAmount    amount returned (in the target token)
     */
    function dispatchConversionEvent(
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        address _trader,
        uint256 _amount,
        uint256 _returnAmount,
        uint256 _feeAmount
    ) internal {
        // fee amount is converted to 255 bits -
        // negative amount means the fee is taken from the source token, positive amount means its taken from the target token
        // currently the fee is always taken from the target token
        // since we convert it to a signed number, we first ensure that it's capped at 255 bits to prevent overflow
        assert(_feeAmount < 2**255);
        emit Conversion(_sourceToken, _targetToken, _trader, _amount, _returnAmount, int256(_feeAmount));
    }

    /**
     * @dev deprecated since version 28, backward compatibility - use only for earlier versions
     */
    function token() public view override returns (IConverterAnchor) {
        return anchor;
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function transferTokenOwnership(address _newOwner) public override ownerOnly {
        transferAnchorOwnership(_newOwner);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function acceptTokenOwnership() public override ownerOnly {
        acceptAnchorOwnership();
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function connectors(IReserveToken _address)
        public
        view
        override
        returns (
            uint256,
            uint32,
            bool,
            bool,
            bool
        )
    {
        Reserve memory reserve = reserves[_address];
        return (reserve.balance, reserve.weight, false, false, reserve.isSet);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function connectorTokens(uint256 _index) public view override returns (IReserveToken) {
        return ConverterBase.reserveTokens[_index];
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function connectorTokenCount() public view override returns (uint16) {
        return reserveTokenCount();
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function getConnectorBalance(IReserveToken _connectorToken) public view override returns (uint256) {
        return reserveBalance(_connectorToken);
    }

    /**
     * @dev deprecated, backward compatibility
     */
    function getReturn(
        IReserveToken _sourceToken,
        IReserveToken _targetToken,
        uint256 _amount
    ) public view returns (uint256, uint256) {
        return targetAmountAndFee(_sourceToken, _targetToken, _amount);
    }
}
