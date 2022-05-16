
pragma solidity ^0.6.2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

////////////////////////////////////////////////////////////////////////////////////////////
/// @title USDC
/// @author Christopher Dixon
////////////////////////////////////////////////////////////////////////////////////////////
/**
@notice the USDC contract is used to simulate an ERC20 with uniswap on kovan
**/
contract USDC is  Ownable, ERC20 {

     constructor() public ERC20(
         "USDC",
         "USDC"
       ){
         _Mint(0x7d4A13FE119C9F36425008a7afCB2737B2bB5C41,10000000000000000000000000000);
         _Mint(0x7f3A152F09324f2aee916CE069D3908603449173,10000000000000000000000000000);
         _Mint(0xC6429e05edE87133537eC17b1f5ab99a0ec6CCEb,1000000000000000);
         _Mint(0xb2bD8248B0253CfD08cd346FF668C82b8d8F6447,1000000000000000);
         _Mint(0x744825189eb3Ba671A3e881143214DA6b187E5b8,1000000000000000);
         _Mint(0x04F901C2B7983103f18d04A3dBA34789Aaee076e,1000000000000000);
         _setupDecimals(6);
         _Mint(msg.sender,10000000000000000000000000000);
     }

     function _Mint(address _to, uint _amount) public onlyOwner {
       _mint(_to, _amount);
     }

     function _Burn(address _from, uint _amount) public onlyOwner {
         _burn(_from, _amount);
     }


}
