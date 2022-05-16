pragma solidity ^0.6.0;

////////////////////////////////////////////////////////////////////////////////////////////
/// @title UniswapLPOracleFactoryI
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The UniswapLPOracleFactoryI contract an abstract contract the Warp platform uses to interface
    With the UniswapOracleFactory to retrieve token prices.
**/

abstract contract UniswapLPOracleFactoryI {
    function createNewOracles(
        address _tokenA,
        address _tokenB,
        address _lpToken
    ) public virtual;

    function OneUSDC() public virtual view returns (uint256);

    function getUnderlyingPrice(address _MMI) public virtual returns (uint256);

    function viewUnderlyingPrice(address _MMI)
        public
        virtual
        view
        returns (uint256);

    function getPriceOfToken(address _token, uint256 _amount)
        public
        virtual
        returns (uint256);

    function viewPriceOfToken(address token, uint256 _amount)
        public
        virtual
        view
        returns (uint256);

    function transferOwnership(address _newOwner) public virtual;

    function _calculatePriceOfLP(
        uint256 supply,
        uint256 value0,
        uint256 value1,
        uint8 supplyDecimals
    ) public virtual pure returns (uint256);
}
