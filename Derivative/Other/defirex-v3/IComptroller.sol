pragma solidity ^0.5.16;

contract IComptroller {
    mapping(address => uint) public compAccrued;

    function claimComp(address holder, address[] memory cTokens) public;

    function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);

    function exitMarket(address cToken) external returns (uint256);

    function getAssetsIn(address account) external view returns (address[] memory);

    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);

    function markets(address cTokenAddress) external view returns (bool, uint);

    struct CompMarketState {
        /// @notice The market's last updated compBorrowIndex or compSupplyIndex
        uint224 index;

        /// @notice The block number the index was last updated at
        uint32 block;
    }

    function compSupplyState(address) view public returns(uint224, uint32);

    function compBorrowState(address) view public returns(uint224, uint32);

//    mapping(address => CompMarketState) public compBorrowState;

    mapping(address => mapping(address => uint)) public compSupplierIndex;

    mapping(address => mapping(address => uint)) public compBorrowerIndex;
}
