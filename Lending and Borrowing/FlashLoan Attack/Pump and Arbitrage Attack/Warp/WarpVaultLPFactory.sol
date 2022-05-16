pragma solidity ^0.6.0;

import "./WarpVaultLP.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpVaultLPFactory
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
The WarpVaultLPFactory contract is designed to produce individual WarpVaultLP contracts
**/

contract WarpVaultLPFactory {
    /**
    @notice createWarpVaultLP allows the contract owner to create a new WarpVaultLP contract for a specific LP token
    @param _timelock is a variable representing the number of seconds the timeWizard will prevent withdraws and borrows from a contracts(one week is 605800 seconds)
    @param _lp is the address for the LP token this Warp Vault will manage
    @param _lpName is the name of the LP token (ex:wETH-wBTC)
    **/
    function createWarpVaultLP(
        uint256 _timelock,
        address _lp,
        string memory _lpName
    ) public returns (address) {
        WarpVaultLP vault = new WarpVaultLP(
            _timelock,
            _lp,
            msg.sender,
            _lpName
        );
        return address(vault);
    }
}
