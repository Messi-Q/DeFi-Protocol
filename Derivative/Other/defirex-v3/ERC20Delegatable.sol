pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

// ECDSA operations for signature
// import "@openzeppelin/contracts-ethereum-package/contracts/cryptography/ECDSA.sol";
import "../../utils/ECDSA.sol";

import "./ERC20.sol";


contract ERC20Delegatable is
    Initializable,
    ERC20
{
    using ECDSA for bytes32;

    struct DelegateBalance {
        uint128 delegatedBalance;       // number of delegated tokens
        uint128 receivedBalance;        // number of received tokens
        mapping(address => uint128) receivedFromBalances;   // [tokenOwner] => amount
    }


    // ** PUBLIC VARIABLES **

    // A record of accounts delegate – ([tokenReceiver] => DelegateBalance)
    mapping(address => DelegateBalance) public delegates;


    // ** EVENTS **

    event Delegated(address indexed owner, address indexed recipient, uint256 amount);
    event Undelegated(address indexed owner, address indexed recipient, uint256 amount);


    // ** MODIFIERS **

    modifier checkDelegates(address _tokenSpender, uint _amountToSpend) {
        uint balance = balanceOf(_tokenSpender);
        uint receivedBalance = delegates[_tokenSpender].receivedBalance;
        require(balance.sub(receivedBalance) >= _amountToSpend, "not enough undelgated tokens");
        _;
    }


    // ** PUBLIC view function **

    function balanceOfWithDelegated(address account) public view returns (uint256) {
        return balanceOf(account).add(delegates[account].delegatedBalance);
    }

    function balanceOfWithoutReceived(address account) public view returns (uint256) {
        return balanceOf(account).sub(delegates[account].receivedBalance);
    }


    // ** PUBLIC function **

    function delgate(address recipient, uint256 amount) public returns(bool) {
        _delegate(msg.sender, recipient, amount);
        return true;
    }

    function undelgate(address recipient, uint256 amount) public returns(bool) {
        _undelegate(msg.sender, recipient, amount);
        return true;
    }


    // ** INTERNAL functions **

    function _delegate(address owner, address recipient, uint256 amount) internal {
        require(owner != recipient, "Unable to delegate to delegator address");

        // UPD delegates states
        delegates[owner].delegatedBalance = uint128(uint256(delegates[owner].delegatedBalance).add(amount));
        delegates[recipient].receivedBalance = uint128(uint256(delegates[recipient].receivedBalance).add(amount));
        delegates[recipient].receivedFromBalances[owner] = uint128(uint256(delegates[recipient].receivedFromBalances[owner]).add(amount));

        // transfer tokens from owner to recipient
        _transfer(owner, recipient, amount);

        emit Delegated(owner, recipient, amount);
    }

    function _undelegate(address owner, address recipient, uint256 amount) internal {
        // UPD delegates states with validation
        delegates[owner].delegatedBalance = uint128(uint256(delegates[owner].delegatedBalance).sub(amount));
        delegates[recipient].receivedBalance = uint128(uint256(delegates[recipient].receivedBalance).sub(amount));
        delegates[recipient].receivedFromBalances[owner] = uint128(uint256(delegates[recipient].receivedFromBalances[owner]).sub(amount));

        // transfer tokens from recipient to owner
        _transfer(recipient, owner, amount);

        emit Undelegated(owner, recipient, amount);
    }


    // ** INTERNAL overrided with CHECK_DELEGATES functions **

    function _transfer(address sender, address recipient, uint256 amount) internal checkDelegates(sender, amount) {
        super._transfer(sender, recipient, uint128(amount));
    }

    function _burn(address account, uint256 amount) internal checkDelegates(account, amount) {
        super._burn(account, uint128(amount));
    }

}