pragma solidity ^0.6.0;

import "../DS/DSMath.sol";
import "../DS/DSProxy.sol";
import "../utils/Discount.sol";
import "../interfaces/IFeeRecipient.sol";
import "../interfaces/IAToken.sol";
import "../interfaces/ILendingPool.sol";
import "../interfaces/ILendingPoolAddressesProvider.sol";
import "../interfaces/IPriceOracleGetterAave.sol";

import "../utils/SafeERC20.sol";
import "../utils/BotRegistry.sol";

contract AaveHelper is DSMath {

    using SafeERC20 for ERC20;

    IFeeRecipient public constant feeRecipient = IFeeRecipient(0x39C4a92Dc506300c3Ea4c67ca4CA611102ee6F2A);

    address public constant DISCOUNT_ADDR = 0x1b14E8D511c9A4395425314f849bD737BAF8208F;

    uint public constant MANUAL_SERVICE_FEE = 400; // 0.25% Fee
    uint public constant AUTOMATIC_SERVICE_FEE = 333; // 0.3% Fee

    address public constant BOT_REGISTRY_ADDRESS = 0x637726f8b08a7ABE3aE3aCaB01A80E2d8ddeF77B;

	address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant AAVE_LENDING_POOL_ADDRESSES = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    uint public constant NINETY_NINE_PERCENT_WEI = 990000000000000000;
    uint16 public constant AAVE_REFERRAL_CODE = 64;

    /// @param _collateralAddress underlying token address
    /// @param _user users address
	function getMaxCollateral(address _collateralAddress, address _user) public view returns (uint256) {
        address lendingPoolAddressDataProvider = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPoolDataProvider();
        address lendingPoolCoreAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPoolCore();
        address priceOracleAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getPriceOracle();

        uint256 pow10 = 10 ** (18 - _getDecimals(_collateralAddress));

        // fetch all needed data
        (,uint256 totalCollateralETH, uint256 totalBorrowsETH,,uint256 currentLTV,,,) = ILendingPool(lendingPoolAddressDataProvider).calculateUserGlobalData(_user);
        (,uint256 tokenLTV,,) = ILendingPool(lendingPoolCoreAddress).getReserveConfiguration(_collateralAddress);
        uint256 collateralPrice = IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(_collateralAddress);
        uint256 userTokenBalance = ILendingPool(lendingPoolCoreAddress).getUserUnderlyingAssetBalance(_collateralAddress, _user);
        uint256 userTokenBalanceEth = wmul(userTokenBalance * pow10, collateralPrice);

		// if borrow is 0, return whole user balance
        if (totalBorrowsETH == 0) {
        	return userTokenBalance;
        }

        uint256 maxCollateralEth = div(sub(mul(currentLTV, totalCollateralETH), mul(totalBorrowsETH, 100)), currentLTV);
		/// @dev final amount can't be higher than users token balance
        maxCollateralEth = maxCollateralEth > userTokenBalanceEth ? userTokenBalanceEth : maxCollateralEth;

        // might happen due to wmul precision
        if (maxCollateralEth >= totalCollateralETH) {
        	return wdiv(totalCollateralETH, collateralPrice) / pow10;
        }

        // get sum of all other reserves multiplied with their liquidation thresholds by reversing formula
        uint256 a = sub(wmul(currentLTV, totalCollateralETH), wmul(tokenLTV, userTokenBalanceEth));
        // add new collateral amount multiplied by its threshold, and then divide with new total collateral
        uint256 newLiquidationThreshold = wdiv(add(a, wmul(sub(userTokenBalanceEth, maxCollateralEth), tokenLTV)), sub(totalCollateralETH, maxCollateralEth));

        // if new threshold is lower than first one, calculate new max collateral with newLiquidationThreshold
        if (newLiquidationThreshold < currentLTV) {
        	maxCollateralEth = div(sub(mul(newLiquidationThreshold, totalCollateralETH), mul(totalBorrowsETH, 100)), newLiquidationThreshold);
        	maxCollateralEth = maxCollateralEth > userTokenBalanceEth ? userTokenBalanceEth : maxCollateralEth;
        }

		return wmul(wdiv(maxCollateralEth, collateralPrice) / pow10, NINETY_NINE_PERCENT_WEI);
	}

	/// @param _borrowAddress underlying token address
	/// @param _user users address
	function getMaxBorrow(address _borrowAddress, address _user) public view returns (uint256) {
		address lendingPoolAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPool();
		address priceOracleAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getPriceOracle();

		(,,,,uint256 availableBorrowsETH,,,) = ILendingPool(lendingPoolAddress).getUserAccountData(_user);

		uint256 borrowPrice = IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(_borrowAddress);

		return wmul(wdiv(availableBorrowsETH, borrowPrice) / (10 ** (18 - _getDecimals(_borrowAddress))), NINETY_NINE_PERCENT_WEI);
	}

    function getMaxBoost(address _borrowAddress, address _collateralAddress, address _user) public view returns (uint256) {
        address lendingPoolAddressDataProvider = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPoolDataProvider();
        address lendingPoolCoreAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getLendingPoolCore();
        address priceOracleAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getPriceOracle();

        (,uint256 totalCollateralETH, uint256 totalBorrowsETH,,uint256 currentLTV,,,) = ILendingPool(lendingPoolAddressDataProvider).calculateUserGlobalData(_user);
        (,uint256 tokenLTV,,) = ILendingPool(lendingPoolCoreAddress).getReserveConfiguration(_collateralAddress);
        totalCollateralETH = div(mul(totalCollateralETH, currentLTV), 100);

        uint256 availableBorrowsETH = wmul(mul(div(sub(totalCollateralETH, totalBorrowsETH), sub(100, tokenLTV)), 100), NINETY_NINE_PERCENT_WEI);
        uint256 borrowPrice = IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(_borrowAddress);

        return wdiv(availableBorrowsETH, borrowPrice) / (10 ** (18 - _getDecimals(_borrowAddress)));
    }

    /// @notice Calculates the fee amount
    /// @param _amount Amount that is converted
    /// @param _user Actuall user addr not DSProxy
    /// @param _gasCost Ether amount of gas we are spending for tx
    /// @param _tokenAddr token addr. of token we are getting for the fee
    /// @return feeAmount The amount we took for the fee
    function getFee(uint _amount, address _user, uint _gasCost, address _tokenAddr) internal returns (uint feeAmount) {
        address priceOracleAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getPriceOracle();

        uint fee = MANUAL_SERVICE_FEE;

        if (BotRegistry(BOT_REGISTRY_ADDRESS).botList(tx.origin)) {
            fee = AUTOMATIC_SERVICE_FEE;
        }

        if (Discount(DISCOUNT_ADDR).isCustomFeeSet(_user)) {
            fee = Discount(DISCOUNT_ADDR).getCustomServiceFee(_user);
        }

        feeAmount = (fee == 0) ? 0 : (_amount / fee);

        if (_gasCost != 0) {
            uint256 price = IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(_tokenAddr);

            _gasCost = wdiv(_gasCost, price) / (10 ** (18 - _getDecimals(_tokenAddr)));

            feeAmount = add(feeAmount, _gasCost);
        }

        // fee can't go over 20% of the whole amount
        if (feeAmount > (_amount / 5)) {
            feeAmount = _amount / 5;
        }

        address walletAddr = feeRecipient.getFeeAddr();

        if (_tokenAddr == ETH_ADDR) {
            payable(walletAddr).transfer(feeAmount);
        } else {
            ERC20(_tokenAddr).safeTransfer(walletAddr, feeAmount);
        }
    }

    /// @notice Calculates the gas cost for transaction
    /// @param _amount Amount that is converted
    /// @param _user Actuall user addr not DSProxy
    /// @param _gasCost Ether amount of gas we are spending for tx
    /// @param _tokenAddr token addr. of token we are getting for the fee
    /// @return gasCost The amount we took for the gas cost
    function getGasCost(uint _amount, address _user, uint _gasCost, address _tokenAddr) internal returns (uint gasCost) {

        if (_gasCost == 0) return 0;

        address priceOracleAddress = ILendingPoolAddressesProvider(AAVE_LENDING_POOL_ADDRESSES).getPriceOracle();
        uint256 price = IPriceOracleGetterAave(priceOracleAddress).getAssetPrice(_tokenAddr);

        _gasCost = wmul(_gasCost, price);
        gasCost = _gasCost;

        // fee can't go over 20% of the whole amount
        if (gasCost > (_amount / 5)) {
            gasCost = _amount / 5;
        }

        address walletAddr = feeRecipient.getFeeAddr();

        if (_tokenAddr == ETH_ADDR) {
            payable(walletAddr).transfer(gasCost);
        } else {
            ERC20(_tokenAddr).safeTransfer(walletAddr, gasCost);
        }
    }


    /// @notice Returns the owner of the DSProxy that called the contract
    function getUserAddress() internal view returns (address) {
        DSProxy proxy = DSProxy(payable(address(this)));

        return proxy.owner();
    }

    /// @notice Approves token contract to pull underlying tokens from the DSProxy
    /// @param _tokenAddr Token we are trying to approve
    /// @param _caller Address which will gain the approval
    function approveToken(address _tokenAddr, address _caller) internal {
        if (_tokenAddr != ETH_ADDR) {
            ERC20(_tokenAddr).safeApprove(_caller, uint256(-1));
        }
    }

    /// @notice Send specific amount from contract to specific user
    /// @param _token Token we are trying to send
    /// @param _user User that should receive funds
    /// @param _amount Amount that should be sent
    function sendContractBalance(address _token, address _user, uint _amount) public {
        if (_amount == 0) return;

        if (_token == ETH_ADDR) {
            payable(_user).transfer(_amount);
        } else {
            ERC20(_token).safeTransfer(_user, _amount);
        }
    }

    function sendFullContractBalance(address _token, address _user) public {
        if (_token == ETH_ADDR) {
            sendContractBalance(_token, _user, address(this).balance);
        } else {
            sendContractBalance(_token, _user, ERC20(_token).balanceOf(address(this)));
        }
    }

    function _getDecimals(address _token) internal view returns (uint256) {
        if (_token == ETH_ADDR) return 18;

        return ERC20(_token).decimals();
    }

    function isAutomation() internal view returns(bool) {
        return BotRegistry(BOT_REGISTRY_ADDRESS).botList(tx.origin);
    }
}
