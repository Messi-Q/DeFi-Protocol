pragma solidity ^0.6.0;

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultSCI
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpVaultSCI contract an abstract contract the WarpControl contract uses to interface
    with a WarpVaultSC contract.
**/

abstract contract WarpVaultSCI {
    uint256 public totalReserves;

    function borrowBalanceCurrent(address account)
        public
        virtual
        returns (uint256);

    function borrowBalancePrior(address account)
        public
        virtual
        view
        returns (uint256);

    function exchangeRateCurrent() public virtual returns (uint256);

    function _borrow(uint256 _borrowAmount, address _borrower) external virtual;

    function _repayLiquidatedLoan(
        address _borrower,
        address _liquidator,
        uint256 _amount
    ) public virtual;

    function setNewInterestModel(address _newModel) public virtual;

    function getSCDecimals() public virtual view returns (uint8);

    function getSCAddress() public virtual view returns (address);

    function updateWarpControl(address _warpControl) public virtual;

    function updateTeam(address _warpTeam) public virtual;

    function viewAccountBalance(address _account)
        public
        virtual
        view
        returns (uint256);
}
