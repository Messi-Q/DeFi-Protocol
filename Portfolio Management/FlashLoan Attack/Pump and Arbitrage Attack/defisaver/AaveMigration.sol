// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../utils/SafeERC20.sol";

import "../../interfaces/IAaveProtocolDataProviderV2.sol";
import "../../interfaces/ILendingPoolV2.sol";
import "../../interfaces/TokenInterface.sol";

import "../../interfaces/IAToken.sol";
import "../../interfaces/ILendingPool.sol";
import "../../interfaces/ILendingPoolAddressesProvider.sol";

contract AaveMigration {
    using SafeERC20 for ERC20;

    address public constant ETH_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address public constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint16 public constant AAVE_REFERRAL_CODE = 64;

    address public constant AAVE_V1_LENDING_POOL_ADDRESSES =
        0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;

    struct MigrateLoanData {
        address market;
        address[] collAssets;
        bool[] isColl;
        address[] borrowAssets;
        uint256[] borrowAmounts;
        uint256[] fees;
        uint256[] modes;
    }

    function migrateLoan(MigrateLoanData memory _loanData) public {
        address lendingPoolCoreV1 =
            ILendingPoolAddressesProvider(AAVE_V1_LENDING_POOL_ADDRESSES).getLendingPoolCore();

        address lendingPoolV2 = ILendingPoolAddressesProviderV2(_loanData.market).getLendingPool();

        // payback AaveV1 loans
        for (uint256 i = 0; i < _loanData.borrowAssets.length; ++i) {
            paybackAaveV1(lendingPoolCoreV1, _loanData.borrowAssets[i], _loanData.borrowAmounts[i]);
        }

        // withdraw from AaveV1 and deposit to V2
        for (uint256 i = 0; i < _loanData.collAssets.length; ++i) {
            address aTokenAddr =
                ILendingPool(lendingPoolCoreV1).getReserveATokenAddress(_loanData.collAssets[i]);

            uint256 withdrawnAmount = withdrawAaveV1(aTokenAddr);

            depositAaveV2(
                lendingPoolV2,
                _loanData.market,
                _loanData.collAssets[i],
                withdrawnAmount,
                _loanData.isColl[i]

            );
        }
    }

    function depositAaveV2(
        address _lendingPoolV2,
        address _market,
        address _tokenAddr,
        uint256 _amount,
        bool _isColl
    ) internal {
        // handle weth
        if (_tokenAddr == ETH_ADDR) {
            TokenInterface(WETH_ADDRESS).deposit{value: _amount}();
            _tokenAddr = WETH_ADDRESS;
        }

        ERC20(_tokenAddr).safeApprove(_lendingPoolV2, _amount);
        ILendingPoolV2(_lendingPoolV2).deposit(
            _tokenAddr,
            _amount,
            address(this),
            AAVE_REFERRAL_CODE
        );

        if (_isColl) {
            setUserUseReserveAsCollateralIfNeeded(_lendingPoolV2, _market, _tokenAddr);
        }
    }

    function withdrawAaveV1(address _aTokenAddr)
        internal
        returns (uint256 amount)
    {
        amount = ERC20(_aTokenAddr).balanceOf(address(this));

        IAToken(_aTokenAddr).redeem(amount);
    }

    function paybackAaveV1(
        address _lendingPoolCore,
        address _tokenAddr,
        uint256 _amount
    ) internal {
        address lendingPool =
            ILendingPoolAddressesProvider(AAVE_V1_LENDING_POOL_ADDRESSES).getLendingPool();

        uint256 ethAmount = 0;

        if (_tokenAddr != WETH_ADDRESS) {
            ERC20(_tokenAddr).safeApprove(_lendingPoolCore, uint(-1));
        } else {
            ethAmount = _amount;
            TokenInterface(WETH_ADDRESS).withdraw(ethAmount);
        }

        ILendingPool(lendingPool).repay{value: ethAmount}(
            _tokenAddr,
            _amount,
            payable(address(this))
        );
    }

    function setUserUseReserveAsCollateralIfNeeded(
        address _lendingPoolV2,
        address _market,
        address _tokenAddr
    ) public {
        IAaveProtocolDataProviderV2 dataProvider = getDataProvider(_market);

        (, , , , , , , , bool collateralEnabled) =
            dataProvider.getUserReserveData(_tokenAddr, address(this));

        if (!collateralEnabled) {
            ILendingPoolV2(_lendingPoolV2).setUserUseReserveAsCollateral(_tokenAddr, true);
        }
    }

    function getDataProvider(address _market) internal view returns (IAaveProtocolDataProviderV2) {
        return
            IAaveProtocolDataProviderV2(
                ILendingPoolAddressesProviderV2(_market).getAddress(
                    0x0100000000000000000000000000000000000000000000000000000000000000
                )
            );
    }
}
