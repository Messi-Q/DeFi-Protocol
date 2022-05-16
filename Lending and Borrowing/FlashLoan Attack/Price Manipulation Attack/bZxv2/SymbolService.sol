// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interface/ILiquidityPoolGetter.sol";

contract SymbolService is Initializable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    struct PerpetualUID {
        address liquidityPool;
        uint256 perpetualIndex;
    }

    mapping(uint256 => PerpetualUID) internal _perpetualUIDs;
    mapping(bytes32 => EnumerableSetUpgradeable.UintSet) internal _perpetualSymbols;
    uint256 internal _nextSymbol;
    uint256 internal _reservedSymbolCount;
    EnumerableSetUpgradeable.AddressSet internal _whitelistedFactories;

    event AllocateSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol);
    event AddWhitelistedFactory(address factory);
    event RemoveWhitelistedFactory(address factory);

    function initialize(uint256 reservedSymbolCount) external virtual initializer {
        __Ownable_init();
        _nextSymbol = reservedSymbolCount;
        _reservedSymbolCount = reservedSymbolCount;
    }

    /**
     * @notice Check if the factory is whitelisted
     * @param factory The address of the factory
     * @return bool True if the factory is whitelisted
     */
    function isWhitelistedFactory(address factory) public view returns (bool) {
        return _whitelistedFactories.contains(factory);
    }

    /**
     * @notice Add the factory to the whitelist. Can only called by owner
     * @param factory The address of the factory
     */
    function addWhitelistedFactory(address factory) public onlyOwner {
        require(factory.isContract(), "factory must be a contract");
        require(!isWhitelistedFactory(factory), "factory already exists");
        _whitelistedFactories.add(factory);
        emit AddWhitelistedFactory(factory);
    }

    /**
     * @notice Remove the factory from the whitelist. Can only called by owner
     * @param factory The address of the factory
     */
    function removeWhitelistedFactory(address factory) public onlyOwner {
        require(isWhitelistedFactory(factory), "factory not found");
        _whitelistedFactories.remove(factory);
        emit RemoveWhitelistedFactory(factory);
    }

    modifier onlyWhitelisted(address liquidityPool) {
        require(AddressUpgradeable.isContract(liquidityPool), "must called by contract");
        (, , address[7] memory addresses, , ) = ILiquidityPoolGetter(liquidityPool)
            .getLiquidityPoolInfo();
        require(_whitelistedFactories.contains(addresses[0]), "wrong factory");
        _;
    }

    /**
     * @notice Get the unique id(liquidity pool + perpetual index) of the perpetual by the symbol
     * @param symbol The symbol
     * @return liquidityPool The address of the liquidity pool
     * @return perpetualIndex The index of the perpetual in the liquidity pool
     */
    function getPerpetualUID(uint256 symbol)
        public
        view
        returns (address liquidityPool, uint256 perpetualIndex)
    {
        PerpetualUID storage perpetualUID = _perpetualUIDs[symbol];
        require(perpetualUID.liquidityPool != address(0), "symbol not found");
        liquidityPool = perpetualUID.liquidityPool;
        perpetualIndex = perpetualUID.perpetualIndex;
    }

    /**
     * @notice Get the symbols of the perpetual by the unique id(liquidity pool + perpetual index)
     * @param liquidityPool The address of the liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return symbols The symbols of the perpetual
     */
    function getSymbols(address liquidityPool, uint256 perpetualIndex)
        public
        view
        returns (uint256[] memory symbols)
    {
        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        uint256 length = _perpetualSymbols[key].length();
        if (length == 0) {
            return symbols;
        }
        symbols = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            symbols[i] = _perpetualSymbols[key].at(i);
        }
    }

    /**
     * @notice Allocate the perpetual an unreserved symbol The perpetual must have no symbol before.
     *         Can only called by whitelisted factory
     * @param liquidityPool The address of the liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return symbol The symbol allocated
     */
    function allocateSymbol(address liquidityPool, uint256 perpetualIndex)
        public
        onlyWhitelisted(msg.sender)
        returns (uint256 symbol)
    {
        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        require(_perpetualSymbols[key].length() == 0, "perpetual already exists");

        symbol = _nextSymbol;
        require(symbol < type(uint256).max, "not enough symbol");
        _perpetualUIDs[symbol] = PerpetualUID({
            liquidityPool: liquidityPool,
            perpetualIndex: perpetualIndex
        });
        _perpetualSymbols[key].add(symbol);
        _nextSymbol = _nextSymbol.add(1);
        emit AllocateSymbol(liquidityPool, perpetualIndex, symbol);
    }

    /**
     * @notice Assign perpetual a reserved symbol. The perpetual must have unreserved symbol
     *         and not have reserved symbol before. Can only called by owner
     * @param liquidityPool The address of the liquidity pool
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @param symbol The symbol assigned
     */
    function assignReservedSymbol(
        address liquidityPool,
        uint256 perpetualIndex,
        uint256 symbol
    ) public onlyOwner onlyWhitelisted(liquidityPool) {
        require(symbol < _reservedSymbolCount, "symbol exceeds reserved symbol count");
        require(_perpetualUIDs[symbol].liquidityPool == address(0), "symbol already exists");

        bytes32 key = _getPerpetualKey(liquidityPool, perpetualIndex);
        require(
            _perpetualSymbols[key].length() == 1 &&
                _perpetualSymbols[key].at(0) >= _reservedSymbolCount,
            "perpetual must have normal symbol and mustn't have reversed symbol"
        );
        _perpetualUIDs[symbol] = PerpetualUID({
            liquidityPool: liquidityPool,
            perpetualIndex: perpetualIndex
        });
        _perpetualSymbols[key].add(symbol);
        emit AllocateSymbol(liquidityPool, perpetualIndex, symbol);
    }

    /**
     * @dev Get the key of the perpetual
     * @param liquidityPool The address of the liquidity pool which the perpetual belongs to
     * @param perpetualIndex The index of the perpetual in the liquidity pool
     * @return bytes32 The key of the perpetual
     */
    function _getPerpetualKey(address liquidityPool, uint256 perpetualIndex)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(liquidityPool, perpetualIndex));
    }
}
