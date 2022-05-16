pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TesterToken is Ownable, ERC20 {

    constructor(
        string memory _tokenName,
        string memory _tokenSymbol
    ) public ERC20(_tokenSymbol, _tokenName) {
    }

    function setDecimals(uint8 decimals) public onlyOwner {
        _setupDecimals(decimals);
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyOwner {
        _burn(_from, _amount);
    }
}
