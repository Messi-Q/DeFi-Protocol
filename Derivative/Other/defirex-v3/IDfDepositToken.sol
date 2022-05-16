pragma solidity ^0.5.16;

interface IDfDepositToken {

    function decimals() external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);
    function balanceOf(address account) external view returns (uint);
    function approve(address spender, uint value) external;
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function mint(address account, uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;

    function balanceOfAt(address account, uint256 snapshotId) external view returns(uint256);
    function balanceOfAtInDai(address account, uint256 snapshotId) external view returns(uint256);
    function totalSupplyAt(uint256 snapshotId) external view returns(uint256);
    function totalSupplyAtInDai(uint256 snapshotId) external view returns(uint256);
    function totalSupply() external view returns(uint256);
    function snapshot() external returns(uint256);
    function snapshot(uint256 price) external returns(uint256);
    function prices(uint256 snapshotId) view external returns(uint256);
}
