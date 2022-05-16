pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../utils/FlashLoanReceiverBase.sol";
import "../../interfaces/DSProxyInterface.sol";
import "../../exchangeV3/DFSExchangeData.sol";

/// @title Contract that receives the FL from Aave for Repays/Boost
contract CompoundSaverFlashLoan is FlashLoanReceiverBase, DFSExchangeData {
    ILendingPoolAddressesProvider public LENDING_POOL_ADDRESS_PROVIDER = ILendingPoolAddressesProvider(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);

    address payable public COMPOUND_SAVER_FLASH_PROXY = 0x97554B4027f673fe786Ff027f8c30d73e6A99560;
    address public constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    using SafeERC20 for ERC20;

    constructor() FlashLoanReceiverBase(LENDING_POOL_ADDRESS_PROVIDER) public {}

    /// @notice Called by Aave when sending back the FL amount
    /// @param _reserve The address of the borrowed token
    /// @param _amount Amount of FL tokens received
    /// @param _fee FL Aave fee
    /// @param _params The params that are sent from the original FL caller contract
   function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params)
    external override {
        // Format the call data for DSProxy
        (bytes memory proxyData, address payable proxyAddr) = packFunctionCall(_amount, _fee, _params);

        // Send Flash loan amount to DSProxy
        sendLoanToProxy(proxyAddr, _reserve, _amount);

        // Execute the DSProxy call
        DSProxyInterface(proxyAddr).execute(COMPOUND_SAVER_FLASH_PROXY, proxyData);

        // Repay the loan with the money DSProxy sent back
        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));

        // if there is some eth left (0x fee), return it to user
        if (address(this).balance > 0) {
            tx.origin.transfer(address(this).balance);
        }
    }

    /// @notice Formats function data call so we can call it through DSProxy
    /// @param _amount Amount of FL
    /// @param _fee Fee of the FL
    /// @param _params Saver proxy params
    /// @return proxyData Formated function call data
    function packFunctionCall(uint _amount, uint _fee, bytes memory _params) internal pure returns (bytes memory proxyData, address payable) {
        (
            bytes memory exDataBytes,
            address[2] memory cAddresses, // cCollAddress, cBorrowAddress
            uint256 gasCost,
            bool isRepay,
            address payable proxyAddr
        )
        = abi.decode(_params, (bytes,address[2],uint256,bool,address));

        ExchangeData memory _exData = unpackExchangeData(exDataBytes);

        uint[2] memory flashLoanData = [_amount, _fee];

        if (isRepay) {
            proxyData = abi.encodeWithSignature("flashRepay((address,address,uint256,uint256,uint256,uint256,address,address,bytes,(address,address,address,uint256,uint256,bytes)),address[2],uint256,uint256[2])", _exData, cAddresses, gasCost, flashLoanData);
        } else {
            proxyData = abi.encodeWithSignature("flashBoost((address,address,uint256,uint256,uint256,uint256,address,address,bytes,(address,address,address,uint256,uint256,bytes)),address[2],uint256,uint256[2])", _exData, cAddresses, gasCost, flashLoanData);
        }

        return (proxyData, proxyAddr);
    }

    /// @notice Send the FL funds received to DSProxy
    /// @param _proxy DSProxy address
    /// @param _reserve Token address
    /// @param _amount Amount of tokens
    function sendLoanToProxy(address payable _proxy, address _reserve, uint _amount) internal {
        if (_reserve != ETH_ADDRESS) {
            ERC20(_reserve).safeTransfer(_proxy, _amount);
        }

        _proxy.transfer(address(this).balance);
    }

    receive() external override(FlashLoanReceiverBase) payable {}
}
