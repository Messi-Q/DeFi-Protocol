pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@uniswap/v2-periphery/contracts/UniswapV2Router02.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "./UniswapLPOracleInstance.sol";
import "./interfaces/ExtendedIERC20.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title UniswapLPOracleFactory
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The UniswapLPOracleFactory contract is designed to produce individual UniswapLPOracleInstance contracts
This contract uses the OpenZeppelin contract Library to inherit functions from
  Ownable.sol
**/

contract UniswapLPOracleFactory is Ownable {
    using SafeMath for uint256;
    address public usdc_add;
    address public factory;
    IUniswapV2Router02 public uniswapRouter;

    mapping(address => address[]) public LPAssetTracker;
    mapping(address => address) public instanceTracker;
    mapping(address => address) public tokenToUSDC;

    /**
    @notice constructor function is fired once during contract creation. This constructor initializes uniswapRouter
            as a usable contract instance within the UniswapLPOracleFactory
    @param usdcAdd is the address of the ERC20 USDC address
    @param _uniFactoryAdd is the address of the uniswap factory contract
    **/
    constructor(
        address usdcAdd,
        address _uniFactoryAdd,
        address _uniRouterAddress
    ) public {
        uniswapRouter = IUniswapV2Router02(_uniRouterAddress);
        usdc_add = usdcAdd;
        factory = _uniFactoryAdd;
    }

    function USDC() public view returns (address) {
        return usdc_add;
    }

    function OneUSDC() public view returns (uint256) {
        return OneToken(usdc_add);
    }

    function OneToken(address token) public view returns (uint256) {
        ExtendedIERC20 ercToken = ExtendedIERC20(token);
        return uint256(10)**uint256(ercToken.decimals());
    }

    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "ZERO_ADDRESS");
    }

    /**
    @notice createNewOracle allows the owner of this contract to deploy deploy two new asset oracle contracts
            when a new LP token is whitelisted. this contract will link the address of an LP token contract to
            two seperate oracles that are designed to look up the price of their respective assets in USDC. This
            will allow us to calculate the price of one at LP token token from the prices of their underlying assets

    @param _tokenA is the address of the first token in an Liquidity pair
    @param _tokenB is the address of the second token in a liquidity pair
    @param _lpToken is the address of the token that this oracle will provide a price feed for
    **/
    function createNewOracles(
        address _tokenA,
        address _tokenB,
        address _lpToken
    ) public onlyOwner {
        (address token0, address token1) = sortTokens(_tokenA, _tokenB);

        address oracle1 = tokenToUSDC[token0];
        if (oracle1 == address(0)) {
            oracle1 = address(
                new UniswapLPOracleInstance(factory, token0, usdc_add)
            );
            tokenToUSDC[token0] = oracle1;
        }

        address oracle2 = tokenToUSDC[token1];
        if (oracle2 == address(0)) {
            oracle2 = address(
                new UniswapLPOracleInstance(factory, token1, usdc_add)
            );
            tokenToUSDC[token1] = oracle2;
        }

        LPAssetTracker[_lpToken] = [oracle1, oracle2];
        instanceTracker[oracle1] = token0;
        instanceTracker[oracle2] = token1;
    }

    /**
    @notice getUnderlyingPrice allows for the price calculation and retrieval of a LP tokens price
    @param _lpToken is the address of the LP token  whos asset price is being retrieved
    @return returns the price of one LP token
    **/
    function getUnderlyingPrice(address _lpToken) public returns (uint256) {
        address[] memory oracleAdds = LPAssetTracker[_lpToken];
        //retreives the oracle contract addresses for each asset that makes up a LP
        UniswapLPOracleInstance oracle1 = UniswapLPOracleInstance(
            oracleAdds[0]
        );
        UniswapLPOracleInstance oracle2 = UniswapLPOracleInstance(
            oracleAdds[1]
        );

        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            factory,
            instanceTracker[oracleAdds[0]],
            instanceTracker[oracleAdds[1]]
        );

        uint256 priceAsset1 = oracle1.consult(
            instanceTracker[oracleAdds[0]],
            reserveA
        );
        uint256 priceAsset2 = oracle2.consult(
            instanceTracker[oracleAdds[1]],
            reserveB
        );

        // Get the total supply of the pool
        IERC20 lpToken = IERC20(_lpToken);
        uint256 totalSupplyOfLP = lpToken.totalSupply();

        return
            _calculatePriceOfLP(
                totalSupplyOfLP,
                priceAsset1,
                priceAsset2,
                lpToken.decimals()
            );
        //return USDC price of the pool divided by totalSupply of its LPs to get price
        //of one LP
    }

    function _calculatePriceOfLP(
        uint256 supply,
        uint256 value0,
        uint256 value1,
        uint8 supplyDecimals
    ) public pure returns (uint256) {
        uint256 totalValue = value0 + value1;
        uint16 shiftAmount = supplyDecimals;
        uint256 valueShifted = totalValue * uint256(10)**shiftAmount;
        uint256 supplyShifted = supply;
        uint256 valuePerSupply = valueShifted / supplyShifted;

        return valuePerSupply;
    }

    /**
    @notice viewUnderlyingPrice allows for the price retrieval of a LP tokens price
    @param _lpToken is the address of the LP token  whos asset price is being retrieved
    @return returns the price of one LP token
    **/
    function viewUnderlyingPrice(address _lpToken)
        public
        view
        returns (uint256)
    {
        address[] memory oracleAdds = LPAssetTracker[_lpToken];
        //retreives the oracle contract addresses for each asset that makes up a LP
        UniswapLPOracleInstance oracle1 = UniswapLPOracleInstance(
            oracleAdds[0]
        );
        UniswapLPOracleInstance oracle2 = UniswapLPOracleInstance(
            oracleAdds[1]
        );
        // instantiates both ase usable oracle instances
        (uint256 reserveA, uint256 reserveB) = UniswapV2Library.getReserves(
            factory,
            instanceTracker[oracleAdds[0]],
            instanceTracker[oracleAdds[1]]
        );

        uint256 priceAsset1 = oracle1.viewPrice(
            instanceTracker[oracleAdds[0]],
            reserveA
        );
        uint256 priceAsset2 = oracle2.viewPrice(
            instanceTracker[oracleAdds[1]],
            reserveB
        );

        // Get the total supply of the pool
        IERC20 lpToken = IERC20(_lpToken);
        uint256 totalSupplyOfLP = lpToken.totalSupply();

        return
            _calculatePriceOfLP(
                totalSupplyOfLP,
                priceAsset1,
                priceAsset2,
                lpToken.decimals()
            );
        //return USDC price of the pool divided by totalSupply of its LPs to get price
        //of one LP
    }

    function viewPriceOfToken(address _token, uint256 _amount)
        public
        view
        returns (uint256)
    {
        require(
            tokenToUSDC[_token] != address(0),
            "Token not registered with a USDC pairing"
        );

        UniswapLPOracleInstance oracle = UniswapLPOracleInstance(
            tokenToUSDC[_token]
        );
        if (_amount == 0) {
            _amount = OneToken(_token);
        }
        return oracle.viewPrice(_token, _amount);
    }

    function getPriceOfToken(address _token, uint256 _amount)
        public
        returns (uint256)
    {
        require(
            tokenToUSDC[_token] != address(0),
            "Token not registered with a USDC pairing"
        );

        UniswapLPOracleInstance oracle = UniswapLPOracleInstance(
            tokenToUSDC[_token]
        );
        if (_amount == 0) {
            _amount = OneToken(_token);
        }
        return oracle.consult(_token, _amount);
    }
}
