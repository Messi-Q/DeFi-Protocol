# Symbol service

Symbol service stores mapping from a short integer to the tuple(address, index), when the address is the address of liquidity pool and index is the index of perpetual storage in the liquidity pool.

New created perpetual has to register to get its id, then any external accessor will be able to query id to the true address and index.

A perpetual can have one unreserved symbol or two symbols: one unreserved symbol and one reserved symbol.

## Unreserved symbol

When a perpetual is created, it will be allocated an unreserved symbol. Unreserved symbol starts with the number of reserved symbols. And it's added one after each allocation. The allocation will fail if the perpetual has symbol before.

The implementation of the function is:
```solidity
allocateSymbol(address liquidityPool, uint256 perpetualIndex)
```

## Reserved symbol

Reserved symbol must be less than the number of reserved symbols. If the perpetual wants to have a reserved symbol, it must have one unreserved symbol and have no reserved symbol before. The governor can assign it a reserved symbol through function:
```solidity
assignReservedSymbol(address liquidityPool, uint256 perpetualIndex, uint256 symbol)
```
