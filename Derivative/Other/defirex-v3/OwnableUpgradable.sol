pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";


contract OwnableUpgradable is Initializable {
    address payable public owner;
    address payable internal newOwnerCandidate;


    function checkAuth() private {
        require(msg.sender == owner, "Permission denied");
    }
    modifier onlyOwner {
        checkAuth();
        _;
    }


    // ** INITIALIZERS – Constructors for Upgradable contracts **

    function initialize() public initializer {
        owner = msg.sender;
    }

    function initialize(address payable newOwner) public initializer {
        owner = newOwner;
    }


    function changeOwner(address payable newOwner) public onlyOwner {
        newOwnerCandidate = newOwner;
    }

    function acceptOwner() public {
        require(msg.sender == newOwnerCandidate);
        owner = newOwnerCandidate;
    }


    uint256[50] private ______gap;
}
