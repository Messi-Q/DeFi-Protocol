pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title WarpWrapperToken
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
@notice the WarpWrapperToken contract is designed  as a token Wrapper to represent ownership of stablecoins added to a specific
        WarpVault. This contract inherits Ownership and ERC20 functionality from the Open Zeppelin Library.
**/
contract WarpWrapperToken is Ownable, ERC20 {
    address public stablecoin;

    ///@notice constructor sets up token names and symbols for the WarpWrapperToken
    constructor(
        address _SC,
        string memory _tokenName,
        string memory _tokenSymbol
    ) public ERC20(_tokenSymbol, _tokenName) {
        stablecoin = _SC;
    }

    /**
    @notice mint is an only owner function that allows the owner to mint new tokens to an input account
    @param _to is the address that will receive the new tokens
    @param _amount is the amount of token they will receive
    **/
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /**
    @notice burn is an only owner function that allows the owner to burn  tokens from an input account
    @param _from is the address where the tokens will be burnt
    @param _amount is the amount of token to be burnt
    **/
    function burn(address _from, uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }
}
