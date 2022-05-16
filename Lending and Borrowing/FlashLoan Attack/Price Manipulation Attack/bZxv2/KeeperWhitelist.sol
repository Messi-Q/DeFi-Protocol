// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

import "../interface/IKeeperWhitelist.sol";

import "../libraries/Utils.sol";

contract KeeperWhitelist is Initializable, OwnableUpgradeable, IKeeperWhitelist {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
    using Utils for EnumerableSetUpgradeable.AddressSet;

    EnumerableSetUpgradeable.AddressSet internal _keepers;

    event AddKeeperToWhitelist(address indexed keeper);
    event RemoveKeeperFromWhitelist(address indexed keeper);

    /**
     * @notice Add an address to keeper whitelist.
     */
    function addKeeper(address keeper) external virtual override onlyOwner {
        require(keeper != address(0), "account is zero-address");
        require(!isKeeper(keeper), "keeper is already in the whitelist");
        bool success = _keepers.add(keeper);
        require(success, "fail to add keeper");
        emit AddKeeperToWhitelist(keeper);
    }

    /**
     * @notice Remove an address from keeper whitelist.
     */
    function removeKeeper(address keeper) external virtual override onlyOwner {
        require(keeper != address(0), "account is zero-address");
        require(isKeeper(keeper), "keeper is not in the whitelist");
        bool success = _keepers.remove(keeper);
        require(success, "fail to remove keeper");
        emit RemoveKeeperFromWhitelist(keeper);
    }

    /**
     * @notice Check if an address is in keeper whitelist.
     */
    function isKeeper(address keeper) public view virtual override returns (bool) {
        return _keepers.contains(keeper);
    }

    /**
     * @notice  Get count of current keepers.
     * @return  Number of keepers.
     */
    function getKeeperCount() public view returns (uint256) {
        return _keepers.length();
    }

    /**
     * @notice  List all local keepers.
     * @param   begin   The begin index of keeper to retrieve.
     * @param   end     The end index of keeper, exclusive.
     * @return  result  An array of keeper addresses.
     */
    function listKeepers(uint256 begin, uint256 end)
        public
        view
        virtual
        returns (address[] memory)
    {
        return _keepers.toArray(begin, end);
    }
}
