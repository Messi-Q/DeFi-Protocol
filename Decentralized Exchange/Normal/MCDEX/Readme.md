# Governance

Governor is primarily used for `LiquidityProvider` voting and reward distribution (stake / mining).

## Vote

Any user provided liquidity in liquidity pool will get some share tokens (also known as `LpToken`) based on current total liquidity in the pool. The share token (which is combined into `GovernorAlpha` contract) can be used to create proposal and vote.

The `GovernorAlpha`  contract is a lite version of Compound `GovernorAlpha` contract, which is only able to execute transaction on its corresponding liquidity pool.

There is also a locking mechanism applied on voted account:

- The share tokens will be locked until the end of voting period (defined by `votingPeriod` method) of proposal;
- If the proposal the voters participated is defeated, their share tokens will be unlocked immediately;
- If the proposal the voters participated is succeeded:
  - For voter casted support for the proposal, the lock time will be extended by `executionDelay` + `unlockDelay` (about 5 days currently);
  - For voter casted against for the proposal, their tokens are unlocked.

## Reward Distribution

Share token holders will get MCB reward if there is incentive plan on the liquidity pool.
