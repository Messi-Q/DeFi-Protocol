pragma solidity ^0.6.0;

import "./WarpVaultSC.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultLPFactory
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpVaultSCFactory contract is designed to produce individual WarpVaultLP contracts
**/

contract WarpVaultSCFactory {
    /**
    @notice createNewWarpVaultSC is used to create new WarpVaultSC contract instances
    @param _InterestRate is the address of the InterestRateModel contract created for this Warp Vault
    @param _StableCoin is the address of the stablecoin contract this WarpVault will manage
    @param _warpTeam is the address of the Warp Team used for fees
    @param _initialExchangeRate is the exchange rate mantissa used to determine the initial exchange rate of stablecoin to warp stablecoin
    @param _timelock is a variable representing the number of seconds the timeWizard will prevent withdraws and borrows from a contracts(one week is 605800 seconds)
    **/
    function createNewWarpVaultSC(
        address _InterestRate,
        address _StableCoin,
        address _warpTeam,
        uint256 _initialExchangeRate,
        uint256 _timelock,
        uint256 _reserveFactorMantissa
    ) public returns (address) {
        WarpVaultSC vault = new WarpVaultSC(
            _InterestRate,
            _StableCoin,
            msg.sender,
            _warpTeam,
            _initialExchangeRate,
            _timelock,
            _reserveFactorMantissa
        );
        return address(vault);
    }
}
