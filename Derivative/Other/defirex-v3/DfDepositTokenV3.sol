pragma solidity ^0.5.16;

import "@openzeppelin/upgrades/contracts/Initializable.sol";

import "../access/Ownable.sol";

import "../token/ERC20/ERC20Detailed.sol";
import "../token/ERC20/ERC20Delegatable.sol";
import "../token/ERC20/ERC20Snapshot.sol";


contract DfDepositToken is
    Initializable,
    ERC20Detailed,
    ERC20Snapshot,
    Ownable,
    ERC20Delegatable
{
    mapping(uint256 => uint256) public prices;
    uint256 public offset;
    // ** INITIALIZER **

    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address payable _controller,
        uint256 _offset
    ) public initializer {
        // Initialize Parents Contracts
        ERC20Detailed.initialize(_name, _symbol, _decimals);
        Ownable.initialize(_controller);
        offset = _offset;
    }


    // ** PUBLIC functions **

    // Transfer to array of addresses
    function transfer(address[] memory recipients, uint256[] memory amounts) public returns(bool) {
        require(recipients.length == amounts.length, "Arrays lengths not equal");

        // transfer to all addresses
        for (uint i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }

        return true;
    }

    function snapshot() public onlyOwner returns (uint256 currentId) {
        currentId = _snapshot();
    }

    function snapshot(uint256 price) onlyOwner public returns (uint256 currentId) {
        currentId = _snapshot();
        prices[currentId] = price;
    }


    /**
     * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
    */
    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        uint256 _offset = offset;
        if (snapshotId <= _offset) return 0;
        snapshotId -= _offset;
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _accountBalanceSnapshots[account]);

        return snapshotted ? value : balanceOf(account);
    }

    /**
     * @dev Retrieves the total supply at the time `snapshotId` was created.
     */
    function totalSupplyAt(uint256 snapshotId) public view returns(uint256) {
        uint256 _offset = offset;
        if (snapshotId <= _offset) return 0;
        snapshotId -= _offset;
        (bool snapshotted, uint256 value) = _valueAt(snapshotId, _totalSupplySnapshots);

        return (snapshotted ? value : totalSupply());
    }

    // ** ONLY_OWNER functions **

    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    function burnFrom(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
    }
}