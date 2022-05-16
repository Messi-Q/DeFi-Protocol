// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.6.12;

import "../interfaces/oracleInterface.sol";
import "../interfaces/oracleProxyInterface.sol";
import "../Errors.sol";

/**
 * @title Bifi's OracleProxy Contract
 * @notice Communicate with the contract that
 * provides the price of token
 * @author Bifi (seinmyung25, Miller-kk, tlatkdgus1, dongchangYoo)
 */
contract oracleProxy is oracleProxyInterface, OracleProxyErrors {
	address payable owner;

	mapping(uint256 => Oracle) oracle;

	struct Oracle {
		bscChainlinkOracleInterface feed;
		uint256 feedUnderlyingPoint;

		bool needPriceConvert;
		uint256 priceConvertID;
	}

	uint256 constant unifiedPoint = 10 ** 18;

	uint256 constant defaultUnderlyingPoint = 8;

	modifier onlyOwner {
		require(msg.sender == owner, ONLY_OWNER);
		_;
	}

	/**
	* @dev Construct a new OracleProxy which manages many oracles
	* @param bnbOracle The address of ether's oracle contract
	* @param usdtOracle The address of usdt's oracle contract
	* @param daiOracle The address of dai's oracle contract
	* @param usdcOracle The address of usdc's oracle contract
	*/
	constructor (address bnbOracle, address etherOracle, address usdtOracle, address daiOracle, address usdcOracle) public
	{
		owner = msg.sender;
		_setOracleFeed(0, bnbOracle, 8, false, 0);
    _setOracleFeed(1, etherOracle, 8, false, 0);
		_setOracleFeed(2, usdtOracle, 18, true, 0);
		_setOracleFeed(3, daiOracle, 18, true, 0);
		_setOracleFeed(4, usdcOracle, 18, true, 0);
	}

	/**
	* @dev Replace the owner of the handler
	* @param _owner the address of the owner to be replaced
	* @return true (TODO: validate results)
	*/
	function ownershipTransfer(address payable _owner) onlyOwner public returns (bool)
	{
		owner = _owner;
		return true;
	}

	/**
	* @dev Gets information about the linked token Oracle.
	* @param tokenID The ID of get token Oracle information
	* @return the address of the token oracle feed and the decimal of the actual token.
	*/
	function getOracleFeed(uint256 tokenID) external view override returns (address, uint256)
	{
		return _getOracleFeed(tokenID);
	}

	/**
	* @dev Set information about the linked token Oracle.
	* @param tokenID tokenID to set token Oracle information
	* @param feedAddr the address of the feed contract
	* that provides the price of the token
	* @param decimals Decimal of the token
	* @return true (TODO: validate results)
	*/
	function setOracleFeed(uint256 tokenID, address feedAddr, uint256 decimals, bool needPriceConvert, uint256 priceConvertID) onlyOwner external override returns (bool)
	{
		return _setOracleFeed(tokenID, feedAddr, decimals, needPriceConvert, priceConvertID);
	}

	/**
	* @dev Gets information about the linked token Oracle.
	* @param tokenID The ID of get token Oracle information
	* @return the address of the token oracle feed and the decimal of the actual token.
	*/
	function _getOracleFeed(uint256 tokenID) internal view returns (address, uint256)
	{
		Oracle memory _oracle = oracle[tokenID];
		address addr = address(_oracle.feed);
		return (addr, _oracle.feedUnderlyingPoint);
	}

	/**
	* @dev Set information about the linked token Oracle.
	* @param tokenID tokenID to set token Oracle information
	* @param feedAddr the address of the feed contract
	* that provides the price of the token
	* @param decimals Decimal of the token
	* @param needPriceConvert true for this oracle feed is not USD, need convert
	* @param priceConvertID convert price feed id(registered)
	* @return true (TODO: validate results)
	*/
	function _setOracleFeed(uint256 tokenID, address feedAddr, uint256 decimals, bool needPriceConvert, uint256 priceConvertID) internal returns (bool)
	{
		Oracle memory _oracle;
		_oracle.feed = bscChainlinkOracleInterface(feedAddr);
		_oracle.feedUnderlyingPoint = (10 ** decimals);

		_oracle.needPriceConvert = needPriceConvert;
		_oracle.priceConvertID = priceConvertID;
		oracle[tokenID] = _oracle;
		return true;
	}

	/**
	* @dev The price of the token is obtained through the price feed contract.
	* @param tokenID The ID of the token that will take the price.
	* @return The token price of a uniform unit.
	*/
	function getTokenPrice(uint256 tokenID) external view override returns (uint256)
	{
		Oracle memory _oracle = oracle[tokenID];
		(, int price, , ,) = _oracle.feed.latestRoundData();
    uint256 underlyingPrice = uint256(price);

		uint256 unifiedPrice = _convertPriceToUnified(underlyingPrice, _oracle.feedUnderlyingPoint);

		if (_oracle.needPriceConvert)
		{
			_oracle = oracle[_oracle.priceConvertID];
      (, price, , ,) = _oracle.feed.latestRoundData();

			uint256 convertFeedUnderlyingPrice = uint256(price);
			uint256 convertPrice = _convertPriceToUnified(convertFeedUnderlyingPrice, oracle[0].feedUnderlyingPoint);
			unifiedPrice = unifiedMul(unifiedPrice, convertPrice);
		}

		require(unifiedPrice != 0, ZERO_PRICE);
		return unifiedPrice;
	}

	/**
	* @dev Get owner's address in manager contract
	* @return The address of owner
	*/
	function getOwner() public view returns (address)
	{
		return owner;
	}

	/**
	* @dev Unify the decimal value of the token price returned by price feed oracle.
	* @param price token price without unified of decimal
	* @param feedUnderlyingPoint Decimal of the token
	* @return The price of tokens with unified decimal
	*/
	function _convertPriceToUnified(uint256 price, uint256 feedUnderlyingPoint) internal pure returns (uint256)
	{
		return div(mul(price, unifiedPoint), feedUnderlyingPoint);
	}

	/* **************** safeMath **************** */
	function mul(uint256 a, uint256 b) internal pure returns (uint256)
	{
		return _mul(a, b);
	}

	function div(uint256 a, uint256 b) internal pure returns (uint256)
	{
		return _div(a, b, "div by zero");
	}

	function _mul(uint256 a, uint256 b) internal pure returns (uint256)
	{
		if (a == 0)
		{
			return 0;
		}

		uint256 c = a * b;
		require((c / a) == b, "mul overflow");
		return c;
	}

	function _div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256)
	{
		require(b > 0, errorMessage);
		return a / b;
	}

	function unifiedMul(uint256 a, uint256 b) internal pure returns (uint256)
	{
		return _div(_mul(a, b), unifiedPoint, "unified mul by zero");
	}
}
