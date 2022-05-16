pragma solidity ^0.5.16;

import "./IERC20.sol";

interface IDfTokenizedDeposit {
    function token() external returns (IERC20);
    function dfWallet() external returns (address);

    function tokenETH() external returns (IERC20);
    function tokenUSDC() external returns (IERC20);
    function tokenWBTC() external returns (IERC20);

    function fundsUnwinded(address) external returns (uint256);
}
