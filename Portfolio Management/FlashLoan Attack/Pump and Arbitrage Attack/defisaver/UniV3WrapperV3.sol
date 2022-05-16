// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../interfaces/ExchangeInterfaceV3.sol";
import "../../interfaces/ISwapRouter.sol";
import "../../interfaces/IQuoter.sol";
import "../../auth/AdminAuth.sol";
import "../../DS/DSMath.sol";

/// @title DFS exchange wrapper for UniswapV3
contract UniV3WrapperV3 is DSMath, ExchangeInterfaceV3, AdminAuth {
    using SafeERC20 for ERC20;

    address public constant KYBER_ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ISwapRouter public constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IQuoter public constant quoter = IQuoter(0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6);

    /// @notice Sells _srcAmount of tokens at UniswapV3
    /// @param _srcAddr From token
    /// @param _srcAmount From amount
    /// @param _additionalData Path for swapping
    /// @return uint amount of tokens received from selling
    function sell(
        address _srcAddr,
        address,
        uint256 _srcAmount,
        bytes calldata _additionalData
    ) external payable override returns (uint256) {
        ERC20(_srcAddr).safeApprove(address(router), _srcAmount);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: _additionalData,
            recipient: msg.sender,
            deadline: block.timestamp + 1,
            amountIn: _srcAmount,
            amountOutMinimum: 1
        });
    
        uint256 amountOut = router.exactInput(params);

        return amountOut;
    }

    /// @notice Buys _destAmount of tokens at UniswapV3
    /// @param _srcAddr From token
    /// @param _destAmount To amount
    /// @param _additionalData Path for swapping
    /// @return uint amount of _srcAddr tokens sent for transaction
    function buy(
        address _srcAddr,
        address,
        uint256 _destAmount,
        bytes calldata _additionalData
    ) external payable override returns (uint256) {
        uint256 srcAmount = getBalance(_srcAddr);

        ERC20(_srcAddr).safeApprove(address(router), srcAmount);

        ISwapRouter.ExactOutputParams memory params = ISwapRouter.ExactOutputParams({
            path: _additionalData,
            recipient: msg.sender,
            deadline: block.timestamp + 1,
            amountOut: _destAmount,
            amountInMaximum: type(uint256).max
        });

        uint256 amountIn = router.exactOutput(params);
        sendLeftOver(_srcAddr);
        return amountIn;
    }

    /// @notice Return a rate for which we can sell an amount of tokens
    /// @param _srcAmount From amount
    /// @param _additionalData path object (encoded path_fee_path_fee_path etc.)
    /// @return uint Rate (price)
    function getSellRate(
        address,
        address,
        uint256 _srcAmount,
        bytes memory _additionalData
    ) public override returns (uint256) {
        uint256 amountOut = quoter.quoteExactInput(_additionalData, _srcAmount);
        return wdiv(amountOut, _srcAmount);
    }

    /// @notice Return a rate for which we can buy an amount of tokens
    /// @param _destAmount To amount
    /// @param _additionalData path object (encoded path_fee_path_fee_path etc.)
    /// @return uint Rate (price)
    function getBuyRate(
        address,
        address,
        uint256 _destAmount,
        bytes memory _additionalData
    ) public override returns (uint256) {
        uint256 amountIn = quoter.quoteExactOutput(_additionalData, _destAmount);
        return wdiv(_destAmount, amountIn);
    }

    /// @notice Send any leftover tokens, we use to clear out srcTokens after buy
    /// @param _srcAddr Source token address
    function sendLeftOver(address _srcAddr) internal {
        payable(msg.sender).transfer(address(this).balance);

        if (_srcAddr != KYBER_ETH_ADDRESS) {
            ERC20(_srcAddr).safeTransfer(msg.sender, ERC20(_srcAddr).balanceOf(address(this)));
        }
    }

    function getBalance(address _tokenAddr) internal view returns (uint256 balance) {
        if (_tokenAddr == KYBER_ETH_ADDRESS) {
            balance = address(this).balance;
        } else {
            balance = ERC20(_tokenAddr).balanceOf(address(this));
        }
    }

    // solhint-disable-next-line no-empty-blocks
    receive() external payable {}
}
