pragma solidity ^0.6.0;

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultLPFactoryI
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpVaultLPFactory contract is designed to produce individual WarpVaultLP contracts
**/

abstract contract WarpVaultLPFactoryI {
    function createWarpVaultLP(
        uint256 _timelock,
        address _lp,
        string memory _lpName
    ) public virtual returns (address);
}
