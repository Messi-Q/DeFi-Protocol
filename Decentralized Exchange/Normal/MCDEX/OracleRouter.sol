// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../../libraries/SafeMathExt.sol";
import "../../interface/IOracle.sol";

// An oracle router calculates the asset price with a given path.
// A path is [(oracle, isInverse)]. The OracleRouter never verifies whether the path is reasonable.
// collateral() and underlyingAsset() only shows correct value if the collateral token is in the 1st item
// and the underlying asset is always in the last item.
//
// Example 1: underlying = eth, collateral = usd, oracle1 = eth/usd = 1000
// [(oracle1, false)], return oracle1 = 1000
//
// Example 2: underlying = usd, collateral = eth, oracle1 = eth/usd
// [(oracle1, true)], return (1 / oracle1) = 0.001
//
// Example 3: underlying = btc, collateral = eth, oracle1 = btc/usd = 10000, oracle2 = eth/usd = 1000
// [(oracle2, true), (oracle1, false)], return (1 / oracle2) * oracle1 = 10
//
// Example 4: underlying = eth, collateral = btc, oracle1 = btc/usd = 10000, oracle2 = usd/eth = 0.001
// [(oracle1, true), (oracle2, true)], return (1 / oracle1) * (1 / oracle2) = 0.1
//
// Example 5: underlying = xxx, collateral = eth, oracle1 = btc/usd = 10000, oracle2 = eth/usd = 1000, oracle3 = xxx/btc = 2
// [(oracle2, true), (oracle1, false), (oracle3, false)], return (1 / oracle2) * oracle1 * oracle3 = 20
//
contract OracleRouter {
    using SafeMathExt for int256;
    using SafeMathExt for uint256;

    struct Route {
        address oracle;
        bool isInverse;
    }

    struct RouteDump {
        address oracle;
        bool isInverse;
        string underlyingAsset;
        string collateral;
    }

    string public constant source = "OracleRouter";
    Route[] internal _path;

    constructor(Route[] memory path_) {
        require(path_.length > 0, "empty path");
        for (uint256 i = 0; i < path_.length; i++) {
            require(path_[i].oracle != address(0), "empty oracle");
            _path.push(Route({ oracle: path_[i].oracle, isInverse: path_[i].isInverse }));
        }
    }

    /**
     * @dev Get collateral symbol.
     *
     *      The OracleRouter never verifies whether the path is reasonable.
     *      collateral() and underlyingAsset() only shows correct value if the collateral token is in
     *      the 1st item and the underlying asset is always in the last item.
     * @return symbol string
     */
    function collateral() public view returns (string memory) {
        if (_path[0].isInverse) {
            return IOracle(_path[0].oracle).underlyingAsset();
        } else {
            return IOracle(_path[0].oracle).collateral();
        }
    }

    /**
     * @dev Get underlying asset symbol.
     *
     *      The OracleRouter never verifies whether the path is reasonable.
     *      collateral() and underlyingAsset() only shows correct value if the collateral token is in
     *      the 1st item and the underlying asset is always in the last item.
     * @return symbol string
     */
    function underlyingAsset() public view returns (string memory) {
        uint256 i = _path.length - 1;
        if (_path[i].isInverse) {
            return IOracle(_path[i].oracle).collateral();
        } else {
            return IOracle(_path[i].oracle).underlyingAsset();
        }
    }

    /**
     * @dev Mark price.
     */
    function priceTWAPLong() external returns (int256 newPrice, uint256 newTimestamp) {
        newPrice = Constant.SIGNED_ONE;
        for (uint256 i = 0; i < _path.length; i++) {
            (int256 p, uint256 t) = IOracle(_path[i].oracle).priceTWAPLong();
            if (_path[i].isInverse && p != 0) {
                p = Constant.SIGNED_ONE.wdiv(p);
            }
            newPrice = newPrice.wmul(p);
            newTimestamp = newTimestamp.max(t);
        }
    }

    /**
     * @dev Index price.
     */
    function priceTWAPShort() external returns (int256 newPrice, uint256 newTimestamp) {
        newPrice = Constant.SIGNED_ONE;
        for (uint256 i = 0; i < _path.length; i++) {
            (int256 p, uint256 t) = IOracle(_path[i].oracle).priceTWAPShort();
            if (_path[i].isInverse && p != 0) {
                p = Constant.SIGNED_ONE.wdiv(p);
            }
            newPrice = newPrice.wmul(p);
            newTimestamp = newTimestamp.max(t);
        }
    }

    /**
     * @dev The market is closed if the market is not in its regular trading period.
     */
    function isMarketClosed() external returns (bool) {
        for (uint256 i = 0; i < _path.length; i++) {
            if (IOracle(_path[i].oracle).isMarketClosed()) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev The oracle service was shutdown and never online again.
     */
    function isTerminated() external returns (bool) {
        for (uint256 i = 0; i < _path.length; i++) {
            if (IOracle(_path[i].oracle).isTerminated()) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Dump the addresses
     */
    function getPath() external view returns (Route[] memory) {
        return _path;
    }

    /**
     * @dev Dump the path with info
     */
    function dumpPath() external view returns (RouteDump[] memory) {
        RouteDump[] memory ret = new RouteDump[](_path.length);
        for (uint256 i = 0; i < _path.length; i++) {
            ret[i].oracle = _path[i].oracle;
            ret[i].isInverse = _path[i].isInverse;
            ret[i].underlyingAsset = IOracle(_path[i].oracle).underlyingAsset();
            ret[i].collateral = IOracle(_path[i].oracle).collateral();
        }
        return ret;
    }
}
