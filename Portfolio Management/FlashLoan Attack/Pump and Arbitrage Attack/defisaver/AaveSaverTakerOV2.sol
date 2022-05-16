pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../AaveHelperV2.sol";
import "../../../auth/AdminAuth.sol";
import "../../../auth/ProxyPermission.sol";
import "../../../utils/DydxFlashLoanBase.sol";
import "../../../loggers/DefisaverLogger.sol";
import "../../../interfaces/ProxyRegistryInterface.sol";
import "../../../interfaces/TokenInterface.sol";
import "../../../interfaces/ERC20.sol";
import "../../../exchangeV3/DFSExchangeData.sol";

/// @title Import Aave position from account to wallet
contract AaveSaverTakerOV2 is ProxyPermission, DFSExchangeData, AaveHelperV2 {

    address payable public constant AAVE_RECEIVER = 0x7c0d3Cf3982142EDA2B992e9F912Ac4dEa662258;

    function repay(address _market, ExchangeData memory _data, uint _rateMode, uint256 _gasCost, uint) public payable {
        address lendingPool = ILendingPoolAddressesProviderV2(_market).getLendingPool();

        // send msg.value for exchange to the receiver
        AAVE_RECEIVER.transfer(msg.value);

        address[] memory assets = new address[](1);
        assets[0] = _data.srcAddr;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _data.srcAmount;

        // for repay we are using regular flash loan with paying back the flash loan + premium
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        // create data
        bytes memory encodedData = packExchangeData(_data);
        bytes memory data = abi.encode(encodedData, _market, _gasCost, _rateMode, true, address(this));

        // give permission to receiver and execute tx
        givePermission(AAVE_RECEIVER);
        ILendingPoolV2(lendingPool).flashLoan(AAVE_RECEIVER, assets, amounts, modes, address(this), data, AAVE_REFERRAL_CODE);
        removePermission(AAVE_RECEIVER);
    }

    function boost(address _market, ExchangeData memory _data, uint _rateMode, uint256 _gasCost, uint) public payable {
        address lendingPool = ILendingPoolAddressesProviderV2(_market).getLendingPool();

        // send msg.value for exchange to the receiver
        AAVE_RECEIVER.transfer(msg.value);

        address[] memory assets = new address[](1);
        assets[0] = _data.srcAddr;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _data.srcAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = _rateMode;

        // create data
        bytes memory encodedData = packExchangeData(_data);
        bytes memory data = abi.encode(encodedData, _market, _gasCost, _rateMode, false, address(this));

        // give permission to receiver and execute tx
        givePermission(AAVE_RECEIVER);
        ILendingPoolV2(lendingPool).flashLoan(AAVE_RECEIVER, assets, amounts, modes, address(this), data, AAVE_REFERRAL_CODE);
        removePermission(AAVE_RECEIVER);
    }
}
