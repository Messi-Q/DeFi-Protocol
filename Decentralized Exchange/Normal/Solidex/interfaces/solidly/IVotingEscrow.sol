pragma solidity 0.8.11;

interface IVotingEscrow {
    function increase_amount(uint256 tokenID, uint256 value) external;
    function increase_unlock_time(uint256 tokenID, uint256 duration) external;
    function merge(uint256 fromID, uint256 toID) external;
    function locked(uint256 tokenID) external view returns (uint256 amount, uint256 unlockTime);
    function setApprovalForAll(address operator, bool approved) external;
    function transferFrom(address from, address to, uint256 tokenID) external;
    function safeTransferFrom(address from, address to, uint tokenId) external;
    function ownerOf(uint tokenId) external view returns (address);
    function balanceOfNFT(uint tokenId) external view returns (uint);
    function isApprovedOrOwner(address, uint) external view returns (bool);
}
