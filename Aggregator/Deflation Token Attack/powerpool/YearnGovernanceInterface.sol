// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface YearnGovernanceInterface {
  function getReward() external;

  function stake(uint256 amount) external;

  function withdraw(uint256 amount) external;

  function voteFor(uint256 id) external;

  function voteAgainst(uint256 id) external;

  function exit() external;

  function register() external;

  function propose(address executor, string calldata hash) external;

  function balanceOf(address) external view returns (uint256);

  function voteLock(address) external view returns (uint256);

  function earned(address) external view returns (uint256);
}
