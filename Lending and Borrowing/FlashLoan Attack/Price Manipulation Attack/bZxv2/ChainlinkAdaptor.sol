// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

import "../../interface/IOracle.sol";

interface IChainlink {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundID,
            int256 price,
            uint256 startedAt,
            uint256 timeStamp,
            uint80 answeredInRound
        );

    function decimals() external view returns (uint8);
}

contract ChainlinkAdaptor is Initializable, ContextUpgradeable, AccessControlUpgradeable, IOracle {
    address public chainlink;
    int256 internal _markPrice;
    uint256 internal _markPriceTimestamp;
    bool internal _isTerminated;
    uint8 internal _chainlinkDecimals;
    string public override collateral;
    string public override underlyingAsset;

    event SetTerminated();

    function initialize(
        address chainlink_,
        string memory collateral_,
        string memory underlyingAsset_
    ) external virtual initializer {
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __ChainlinkAdaptor_init_unchained(chainlink_, collateral_, underlyingAsset_);
    }

    function __ChainlinkAdaptor_init_unchained(
        address chainlink_,
        string memory collateral_,
        string memory underlyingAsset_
    ) internal initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        chainlink = chainlink_;
        collateral = collateral_;
        underlyingAsset = underlyingAsset_;
        _chainlinkDecimals = IChainlink(chainlink).decimals();
        require(_chainlinkDecimals <= 18, "decimals exceeds 18");
    }

    function isMarketClosed() public pure override returns (bool) {
        return false;
    }

    function isTerminated() public view override returns (bool) {
        return _isTerminated;
    }

    function priceTWAPLong() public override returns (int256, uint256) {
        updatePrice();
        return (_markPrice, _markPriceTimestamp);
    }

    function priceTWAPShort() public override returns (int256, uint256) {
        return priceTWAPLong();
    }

    function setTerminated() external {
        require(!_isTerminated, "already terminated");
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "role");
        _isTerminated = true;
        emit SetTerminated();
    }

    function updatePrice() public {
        if (!_isTerminated) {
            (, _markPrice, , _markPriceTimestamp, ) = IChainlink(chainlink).latestRoundData();
            require(
                _markPrice > 0 &&
                    _markPrice <= type(int256).max / int256(10**(18 - _chainlinkDecimals)) &&
                    _markPriceTimestamp > 0,
                "invalid chainlink oracle data"
            );
            _markPrice = _markPrice * int256(10**(18 - _chainlinkDecimals));
        }
    }
}
