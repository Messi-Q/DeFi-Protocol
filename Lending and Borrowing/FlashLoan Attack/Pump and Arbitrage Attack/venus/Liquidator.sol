pragma solidity ^0.5.16;

import "./ComptrollerInterface.sol";
import "./EIP20Interface.sol";
import "./SafeMath.sol";
import "./VBNB.sol";
import "./VBep20.sol";
import "./Utils/ReentrancyGuard.sol";
import "./Utils/WithAdmin.sol";

contract Liquidator is WithAdmin, ReentrancyGuard {

    /// @notice Address of vBNB contract.
    VBNB public vBnb;

    /// @notice Address of Venus Unitroller contract.
    IComptroller comptroller;

    /// @notice Address of Venus Treasury.
    address public treasury;

    /// @notice Percent of seized amount that goes to treasury.
    uint256 public treasuryPercentMantissa;

    /// @notice Emitted when once changes the percent of the seized amount
    ///         that goes to treasury.
    event NewLiquidationTreasuryPercent(uint256 oldPercent, uint256 newPercent);

    /// @notice Event emitted when a borrow is liquidated
    event LiquidateBorrowedTokens(address liquidator, address borrower, uint256 repayAmount, address vTokenCollateral, uint256 seizeTokensForTreasury, uint256 seizeTokensForLiquidator);

    using SafeMath for uint256;

    constructor(
        address admin_,
        address payable vBnb_,
        address comptroller_,
        address treasury_,
        uint256 treasuryPercentMantissa_
    )
        public
        WithAdmin(admin_)
        ReentrancyGuard()
    {
        vBnb = VBNB(vBnb_);
        comptroller = IComptroller(comptroller_);
        treasury = treasury_;
        treasuryPercentMantissa = treasuryPercentMantissa_;
    }

    /// @notice Liquidates a borrow and splits the seized amount between treasury and
    ///         liquidator. The liquidators should use this interface instead of calling
    ///         vToken.liquidateBorrow(...) directly.
    /// @dev For BNB borrows msg.value should be equal to repayAmount; otherwise msg.value
    ///      should be zero.
    /// @param vToken Borrowed vToken
    /// @param borrower The address of the borrower
    /// @param repayAmount The amount to repay on behalf of the borrower
    /// @param vTokenCollateral The collateral to seize
    function liquidateBorrow(
        address vToken,
        address borrower,
        uint256 repayAmount,
        VToken vTokenCollateral
    )
        external
        payable
        nonReentrant
    {
        uint256 ourBalanceBefore = vTokenCollateral.balanceOf(address(this));
        if (vToken == address(vBnb)) {
            require(repayAmount == msg.value, "wrong amount");
            vBnb.liquidateBorrow.value(msg.value)(borrower, vTokenCollateral);
        } else {
            require(msg.value == 0, "you shouldn't pay for this");
            _liquidateBep20(VBep20(vToken), borrower, repayAmount, vTokenCollateral);
        }
        uint256 ourBalanceAfter = vTokenCollateral.balanceOf(address(this));
        uint256 seizedAmount = ourBalanceAfter.sub(ourBalanceBefore);
        (uint256 ours, uint256 theirs) = _distributeLiquidationIncentive(vTokenCollateral, seizedAmount);
        emit LiquidateBorrowedTokens(msg.sender, borrower, repayAmount, address(vTokenCollateral), ours, theirs);
    }

    /// @notice Sets the new percent of the seized amount that goes to treasury. Should
    ///         be less than or equal to comptroller.liquidationIncentiveMantissa().
    /// @param newTreasuryPercentMantissa New treasury percent (scaled by 10^18).
    function setTreasuryPercent(uint256 newTreasuryPercentMantissa) external onlyAdmin {
        require(
            newTreasuryPercentMantissa <= comptroller.liquidationIncentiveMantissa(),
            "appetite too big"
        );
        emit NewLiquidationTreasuryPercent(treasuryPercentMantissa, newTreasuryPercentMantissa);
        treasuryPercentMantissa = newTreasuryPercentMantissa;
    }

    /// @dev Transfers BEP20 tokens to self, then approves vToken to take these tokens.
    function _liquidateBep20(
        VBep20 vToken,
        address borrower,
        uint256 repayAmount,
        VToken vTokenCollateral
    )
        internal
    {
        EIP20Interface borrowedToken = EIP20Interface(vToken.underlying());
        borrowedToken.transferFrom(msg.sender, address(this), repayAmount);
        borrowedToken.approve(address(vToken), repayAmount);
        requireNoError(
            vToken.liquidateBorrow(borrower, repayAmount, vTokenCollateral),
            "failed to liquidate"
        );
    }

    /// @dev Splits the received vTokens between the liquidator and treasury.
    function _distributeLiquidationIncentive(VToken vTokenCollateral, uint256 siezedAmount)
        internal returns (uint256 ours, uint256 theirs)
    {
        (ours, theirs) = _splitLiquidationIncentive(siezedAmount);
        require(
            vTokenCollateral.transfer(msg.sender, theirs),
            "failed to transfer to liquidator"
        );
        require(
            vTokenCollateral.transfer(treasury, ours),
            "failed to transfer to treasury"
        );
        return (ours, theirs);
    }

    /// @dev Computes the amounts that would go to treasury and to the liquidator.
    function _splitLiquidationIncentive(uint256 seizedAmount)
        internal
        view
        returns (uint256 ours, uint256 theirs)
    {
        uint256 totalIncentive = comptroller.liquidationIncentiveMantissa();
        uint256 seizedForRepayment = seizedAmount.mul(1e18).div(totalIncentive);
        ours = seizedForRepayment.mul(treasuryPercentMantissa).div(1e18);
        theirs = seizedAmount.sub(ours);
        return (ours, theirs);
    }

    function requireNoError(uint errCode, string memory message) internal pure {
        if (errCode == uint(0)) {
            return;
        }

        bytes memory fullMessage = new bytes(bytes(message).length + 5);
        uint i;

        for (i = 0; i < bytes(message).length; i++) {
            fullMessage[i] = bytes(message)[i];
        }

        fullMessage[i+0] = byte(uint8(32));
        fullMessage[i+1] = byte(uint8(40));
        fullMessage[i+2] = byte(uint8(48 + ( errCode / 10 )));
        fullMessage[i+3] = byte(uint8(48 + ( errCode % 10 )));
        fullMessage[i+4] = byte(uint8(41));

        require(errCode == uint(0), string(fullMessage));
    }
}
