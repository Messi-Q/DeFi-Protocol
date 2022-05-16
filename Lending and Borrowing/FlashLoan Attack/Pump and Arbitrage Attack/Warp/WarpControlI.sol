pragma solidity ^0.6.0;

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultI
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpControlI contract is an abstract contract used by individual WarpVault contracts to call the
  maxWithdrawAllowed function on the WarpControl contract
**/

abstract contract WarpControlI {
    function getMaxWithdrawAllowed(address account, address lpToken)
        public
        virtual
        returns (uint256);

    function viewMaxWithdrawAllowed(address account, address lpToken)
        public
        virtual
        view
        returns (uint256);

    function viewPriceOfCollateral(address lpToken)
        public
        virtual
        view
        returns (uint256);

    function addMemberToGroup(address _refferalCode, address _member)
        public
        virtual;

    function checkIfGroupMember(address _account)
        public
        virtual
        view
        returns (bool);

    function getTotalAvailableCollateralValue(address _account)
        public
        virtual
        returns (uint256);

    function viewTotalAvailableCollateralValue(address _account)
        public
        virtual
        view
        returns (uint256);

    function viewPriceOfToken(address token)
        public
        virtual
        view
        returns (uint256);

    function viewTotalBorrowedValue(address _account)
        public
        virtual
        view
        returns (uint256);

    function getTotalBorrowedValue(address _account)
        public
        virtual
        returns (uint256);

    function calcBorrowLimit(uint256 _collateralValue)
        public
        virtual
        pure
        returns (uint256);

    function calcCollateralRequired(uint256 _borrowAmount)
        public
        virtual
        view
        returns (uint256);

    function getBorrowLimit(address _account) public virtual returns (uint256);

    function viewBorrowLimit(address _account)
        public
        virtual
        view
        returns (uint256);

    function liquidateAccount(address _borrower) public virtual;
}
