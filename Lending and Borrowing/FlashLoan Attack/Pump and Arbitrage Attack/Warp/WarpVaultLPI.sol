pragma solidity ^0.6.0;

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultLPI
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpVaultLPI contract an abstract contract the WarpControl contract uses to interface
    with a WarpVaultLP contract.
**/

abstract contract WarpVaultLPI {
    function getAssetAdd() public virtual view returns (address);

    function collateralOfAccount(address _account)
        public
        virtual
        view
        returns (uint256);

    function _liquidateAccount(address _account, address _liquidator)
        public
        virtual;

    function updateWarpControl(address _warpControl) public virtual;
}
