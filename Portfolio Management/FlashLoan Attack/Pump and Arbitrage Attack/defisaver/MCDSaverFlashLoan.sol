pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../mcd/saver/MCDSaverProxy.sol";
import "../../utils/FlashLoanReceiverBase.sol";
import "../../exchangeV3/DFSExchangeCore.sol";

/// @title Receiver of Aave flash loan and performs the fl repay/boost logic
contract MCDSaverFlashLoan is MCDSaverProxy, AdminAuth, FlashLoanReceiverBase {
    ILendingPoolAddressesProvider public LENDING_POOL_ADDRESS_PROVIDER =
        ILendingPoolAddressesProvider(0x24a42fD28C976A61Df5D00D0599C34c4f90748c8);

    constructor() public FlashLoanReceiverBase(LENDING_POOL_ADDRESS_PROVIDER) {}

    struct SaverData {
        uint256 cdpId;
        uint256 gasCost;
        uint256 loanAmount;
        uint256 fee;
        address joinAddr;
        ManagerType managerType;
    }

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    ) external override {
        (
            bytes memory exDataBytes,
            uint256 cdpId,
            uint256 gasCost,
            address joinAddr,
            bool isRepay,
            uint8 managerType
        ) = abi.decode(_params, (bytes, uint256, uint256, address, bool, uint8));

        ExchangeData memory exchangeData = unpackExchangeData(exDataBytes);

        SaverData memory saverData = SaverData({
            cdpId: cdpId,
            gasCost: gasCost,
            loanAmount: _amount,
            fee: _fee,
            joinAddr: joinAddr,
            managerType: ManagerType(managerType)
        });

        if (isRepay) {
            repayWithLoan(exchangeData, saverData);
        } else {
            boostWithLoan(exchangeData, saverData);
        }

        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));

        // if there is some eth left (0x fee), return it to user
        if (address(this).balance > 0) {
            tx.origin.transfer(address(this).balance);
        }
    }

    function boostWithLoan(ExchangeData memory _exchangeData, SaverData memory _saverData)
        internal
    {
        address managerAddr = getManagerAddr(_saverData.managerType);
        address user = getOwner(Manager(managerAddr), _saverData.cdpId);

        // Draw users Dai
        uint256 maxDebt = getMaxDebt(
            managerAddr,
            _saverData.cdpId,
            Manager(managerAddr).ilks(_saverData.cdpId)
        );
        uint256 daiDrawn = drawDai(
            managerAddr,
            _saverData.cdpId,
            Manager(managerAddr).ilks(_saverData.cdpId),
            maxDebt
        );

        // Swap
        _exchangeData.srcAmount = sub(
            add(daiDrawn, _saverData.loanAmount),
            takeFee(_saverData.gasCost, add(daiDrawn, _saverData.loanAmount))
        );

        _exchangeData.user = user;
        _exchangeData.dfsFeeDivider = isAutomation() ? AUTOMATIC_SERVICE_FEE : MANUAL_SERVICE_FEE;
        (, uint256 swapedAmount) = _sell(_exchangeData);

        // Return collateral
        addCollateral(managerAddr, _saverData.cdpId, _saverData.joinAddr, swapedAmount);

        // Draw Dai to repay the flash loan
        drawDai(
            managerAddr,
            _saverData.cdpId,
            Manager(managerAddr).ilks(_saverData.cdpId),
            add(_saverData.loanAmount, _saverData.fee)
        );

        logger.Log(
            address(this),
            msg.sender,
            "MCDFlashBoost",
            abi.encode(_saverData.cdpId, user, _exchangeData.srcAmount, swapedAmount)
        );
    }

    function repayWithLoan(ExchangeData memory _exchangeData, SaverData memory _saverData)
        internal
    {
        address managerAddr = getManagerAddr(_saverData.managerType);

        address user = getOwner(Manager(managerAddr), _saverData.cdpId);
        bytes32 ilk = Manager(managerAddr).ilks(_saverData.cdpId);

        // Draw collateral
        uint256 maxColl = getMaxCollateral(managerAddr, _saverData.cdpId, ilk, _saverData.joinAddr);
        uint256 collDrawn = drawCollateral(
            managerAddr,
            _saverData.cdpId,
            _saverData.joinAddr,
            maxColl
        );

        // Swap
        _exchangeData.srcAmount = add(_saverData.loanAmount, collDrawn);
        _exchangeData.user = user;
        _exchangeData.dfsFeeDivider = isAutomation() ? AUTOMATIC_SERVICE_FEE : MANUAL_SERVICE_FEE;
        (, uint256 paybackAmount) = _sell(_exchangeData);

        paybackAmount = sub(paybackAmount, takeFee(_saverData.gasCost, paybackAmount));

        // Payback the debt
        paybackDebt(managerAddr, _saverData.cdpId, ilk, paybackAmount, user);

        // Draw collateral to repay the flash loan
        drawCollateral(
            managerAddr,
            _saverData.cdpId,
            _saverData.joinAddr,
            add(_saverData.loanAmount, _saverData.fee)
        );

        logger.Log(
            address(this),
            msg.sender,
            "MCDFlashRepay",
            abi.encode(_saverData.cdpId, user, _exchangeData.srcAmount, paybackAmount)
        );
    }

    receive() external payable override(FlashLoanReceiverBase, DFSExchangeCore) {}
}
