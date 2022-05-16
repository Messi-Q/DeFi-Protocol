interface IDfVenusFarm {
    function deposit(uint256 _wantAmt) external returns (uint256);

    function withdraw(uint256 _wantAmt) external returns (uint256);

    function getFundsByAccount(address _userWallet) external returns (uint256);
}