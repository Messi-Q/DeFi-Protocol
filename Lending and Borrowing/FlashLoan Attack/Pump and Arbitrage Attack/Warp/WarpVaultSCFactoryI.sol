pragma solidity ^0.6.0;

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultSCFactoryI
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpVaultSCFactoryI contract is used by the Warp Control contract to interface with the WarpVaultSCFactory contract
**/

abstract contract WarpVaultSCFactoryI {
    function createNewWarpVaultSC(
        address _InterestRate,
        address _StableCoin,
        address _warpTeam,
        uint256 _initialExchangeRate,
        uint256 _timelock,
        uint256 _reserveFactorMantissa
    ) public virtual returns (address);
}
