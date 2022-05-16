pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";
// import "../openzeppelin/upgrades/contracts/Initializable.sol";

import "./OwnableUpgradable.sol";


contract AdminableUpgradable is Initializable, OwnableUpgradable {
    mapping(address => bool) public admins;


    function checkAuthAdmin() private {
        require(msg.sender == owner || admins[msg.sender], "Permission denied");
    }
    modifier onlyOwnerOrAdmin {
        checkAuthAdmin();
        _;
    }


    // Initializer – Constructor for Upgradable contracts
    function initialize() public initializer {
        OwnableUpgradable.initialize();  // Initialize Parent Contract
    }

    function initialize(address payable newOwner) public initializer {
        OwnableUpgradable.initialize(newOwner);  // Initialize Parent Contract
    }


    function setAdminPermission(address _admin, bool _status) public onlyOwner {
        admins[_admin] = _status;
    }

//    function setAdminPermission(address[] memory _admins, bool _status) public onlyOwner {
//        for (uint i = 0; i < _admins.length; i++) {
//            admins[_admins[i]] = _status;
//        }
//    }


    uint256[50] private ______gap;
}