pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

contract UniswapLPOracleInstance is Ownable {
    using SafeMath for uint256;

    // fixed window oracle that recomputes the average price for the entire period once every period
    // note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period

    using FixedPoint for *;

    uint256 public constant PERIOD = 1 hours;

    IUniswapV2Pair public pair;
    address public token0;
    address public token1;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;
    bool public firstRun;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    /**
    @notice the constructor function is fired once during token creation to initialize the oracle contract to a specific token pair
    @param _factory is the address of the Uniswap factory contract
    @param _tokenA is the address of the asset being looked up
    @param _tokenB is the address of the USDC token
    **/
    constructor(
        address _factory,
        address _tokenA,
        address _tokenB
    ) public {
        if (_tokenA == _tokenB) {
            price0Average = FixedPoint.uq112x112(uint224(1));
            price1Average = FixedPoint.uq112x112(uint224(1));
        } else {
            IUniswapV2Pair _pair = IUniswapV2Pair(
                UniswapV2Library.pairFor(_factory, _tokenA, _tokenB)
            );
            pair = _pair;
            token0 = _pair.token0();
            token1 = _pair.token1();
            price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
            price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
            uint112 reserve0;
            uint112 reserve1;
            (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
            require(reserve0 != 0 && reserve1 != 0, "NO_RESERVES"); // ensure that there's liquidity in the pair
            firstRun = true;
            update();
            firstRun = false;
        }
    }

    /**
    @notice update updates the prices for the input token pair over a set 24hour period
    @dev this is an internal function called by consult if the timeElapsed is greater than 24 hours
    **/
    function update() public {
        (
            uint256 price0Cumulative,
            uint256 price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        //check if this is the first update
        if (timeElapsed >= PERIOD || firstRun == true) {
            // ensure that at least one full period has passed since the last update
            // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
            price0Average = FixedPoint.uq112x112(
                uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
            );
            price1Average = FixedPoint.uq112x112(
                uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
            );

            price0CumulativeLast = price0Cumulative;
            price1CumulativeLast = price1Cumulative;
            blockTimestampLast = blockTimestamp;
        }
    }

    /**
    @notice consult returns the price of a token in USDC
    @return price is the price of one asset in USDC(example 1WETH in USDC)
    **/
    function consult(address token, uint256 amount)
        external
        returns (uint256 price)
    {
        if (token0 == address(0)) {
            return amount;
        }

        if (token == token0) {
            update();
            price = price0Average.mul(amount).decode144();
        } else {
            require(token == token1, "INVALID_TOKEN");
            price = price1Average.mul(amount).decode144();
        }
    }

    /**
    @notice viewPrice is a view function that retreives the current price without having to run the update function
    @return price is the price of one asset in USDC(example 1WETH in USDC)
    **/
    function viewPrice(address token, uint256 amount)
        external
        view
        returns (uint256 price)
    {
        if (token0 == address(0)) {
            return amount;
        }

        if (token == token0) {
            price = price0Average.mul(amount).decode144();
        } else {
            require(token == token1, "INVALID_TOKEN");
            price = price1Average.mul(amount).decode144();
        }
    }
}
