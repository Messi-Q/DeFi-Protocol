pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../AaveHelper.sol";
import "../../exchangeV3/DFSExchangeCore.sol";
import "../../interfaces/IAToken.sol";
import "../../interfaces/ILendingPool.sol";
import "../../loggers/DefisaverLogger.sol";
import "../../utils/GasBurner.sol";

contract AaveSaverProxy is GasBurner, DFSExchangeCore, AaveHelper {

	address public constant DEFISAVER_LOGGER = 0x5c55B921f590a89C1Ebe84dF170E655a82b62126;

    uint public constant VARIABLE_RATE = 2;

	function repay(ExchangeData memory _data, uint _gasCost) public payable burnGas(20) {

		address lendingPoolCore = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPoolCore();
		address lendingPool = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPool();
		address payable user = payable(getUserAddress());

		// redeem collateral
		address aTokenCollateral = ILendingPool(lendingPoolCore).getReserveATokenAddress(_data.srcAddr);
		// uint256 maxCollateral = IAToken(aTokenCollateral).balanceOf(address(this));
		// don't swap more than maxCollateral
		// _data.srcAmount = _data.srcAmount > maxCollateral ? maxCollateral : _data.srcAmount;
		IAToken(aTokenCollateral).redeem(_data.srcAmount);

		uint256 destAmount = _data.srcAmount;
		if (_data.srcAddr != _data.destAddr) {
            _data.dfsFeeDivider = isAutomation() ? AUTOMATIC_SERVICE_FEE : MANUAL_SERVICE_FEE;
            _data.user = user;
			// swap
			(, destAmount) = _sell(_data);
			destAmount -= getGasCost(destAmount, user, _gasCost, _data.destAddr);
		} else {
			destAmount -= getGasCost(destAmount, user, _gasCost, _data.destAddr);
		}

		// payback
		if (_data.destAddr == ETH_ADDR) {
			ILendingPool(lendingPool).repay{value: destAmount}(_data.destAddr, destAmount, payable(address(this)));
		} else {
			approveToken(_data.destAddr, lendingPoolCore);
			ILendingPool(lendingPool).repay(_data.destAddr, destAmount, payable(address(this)));
		}

		// first return 0x fee to msg.sender as it is the address that actually sent 0x fee
		sendContractBalance(ETH_ADDR, tx.origin, min(address(this).balance, msg.value));
		// send all leftovers from dest addr to proxy owner
		sendFullContractBalance(_data.destAddr, user);

		DefisaverLogger(DEFISAVER_LOGGER).Log(address(this), msg.sender, "AaveRepay", abi.encode(_data.srcAddr, _data.destAddr, _data.srcAmount, destAmount));
	}

	function boost(ExchangeData memory _data, uint _gasCost) public payable burnGas(20) {
		address lendingPoolCore = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPoolCore();
		address lendingPool = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPool();
		(,,,uint256 borrowRateMode,,,,,,bool collateralEnabled) = ILendingPool(lendingPool).getUserReserveData(_data.destAddr, address(this));
		address payable user = payable(getUserAddress());

		// skipping this check as its too expensive
		// uint256 maxBorrow = getMaxBoost(_data.srcAddr, _data.destAddr, address(this));
		// _data.srcAmount = _data.srcAmount > maxBorrow ? maxBorrow : _data.srcAmount;

		// borrow amount
		ILendingPool(lendingPool).borrow(_data.srcAddr, _data.srcAmount, borrowRateMode == 0 ? VARIABLE_RATE : borrowRateMode, AAVE_REFERRAL_CODE);

		uint256 destAmount;
		if (_data.destAddr != _data.srcAddr) {
            _data.dfsFeeDivider = isAutomation() ? AUTOMATIC_SERVICE_FEE : MANUAL_SERVICE_FEE;
            _data.user = user;

			// swap
			(, destAmount) = _sell(_data);
            destAmount -= getGasCost(destAmount, user, _gasCost, _data.destAddr);

		} else {
			destAmount = _data.srcAmount;
            destAmount -= getGasCost(destAmount, user, _gasCost, _data.destAddr);

		}

		if (_data.destAddr == ETH_ADDR) {
			ILendingPool(lendingPool).deposit{value: destAmount}(_data.destAddr, destAmount, AAVE_REFERRAL_CODE);
		} else {
			approveToken(_data.destAddr, lendingPoolCore);
			ILendingPool(lendingPool).deposit(_data.destAddr, destAmount, AAVE_REFERRAL_CODE);
		}

		if (!collateralEnabled) {
            ILendingPool(lendingPool).setUserUseReserveAsCollateral(_data.destAddr, true);
        }

		// returning to msg.sender as it is the address that actually sent 0x fee
		sendContractBalance(ETH_ADDR, tx.origin, min(address(this).balance, msg.value));
		// send all leftovers from dest addr to proxy owner
		sendFullContractBalance(_data.destAddr, user);

		DefisaverLogger(DEFISAVER_LOGGER).Log(address(this), msg.sender, "AaveBoost", abi.encode(_data.srcAddr, _data.destAddr, _data.srcAmount, destAmount));
	}
}
