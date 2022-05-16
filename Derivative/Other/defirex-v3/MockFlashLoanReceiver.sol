pragma solidity ^0.5.0;

// import "@openzeppelin/contracts/math/SafeMath.sol";
import "../../utils/SafeMath.sol";

import "../base/FlashLoanReceiverBase.sol";


contract FlashLoanReceiver is FlashLoanReceiverBase {

    using SafeMath for uint256;

    /**
        Must be implemented in the child contract
     */
    function _actionAfterFlashLoanReceived(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes memory _params
    ) internal;


    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    ) external {

        //check the contract has the specified balance
        require(_amount <= getBalanceInternal(address(this), _reserve),
            "Invalid balance for the contract");

        // Action after flashloan received from Aave
        _actionAfterFlashLoanReceived(_reserve, _amount, _fee, _params);

        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));
    }
}