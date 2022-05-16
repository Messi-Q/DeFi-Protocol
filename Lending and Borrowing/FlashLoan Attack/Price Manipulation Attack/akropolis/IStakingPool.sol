// SPDX-License-Identifier: AGPL V3.0
pragma solidity ^0.6.12;

interface IStakingPool {
    function withdrawStakeForSwap(
        address _user,
        address _token,
        bytes calldata _data
    ) external returns (uint256);

    function withdrawRewardForSwap(address _user, address _token) external returns (uint256);

    function rewardBalanceOf(address _user, address _token) external returns (uint256);
}
