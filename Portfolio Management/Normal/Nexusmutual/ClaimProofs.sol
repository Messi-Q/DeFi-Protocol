// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.5.0;

contract ClaimProofs {

  event ProofAdded(uint indexed coverId, address indexed owner, string ipfsHash);

  function addProof(uint _coverId, string calldata _ipfsHash) external {
    emit ProofAdded(_coverId, msg.sender, _ipfsHash);
  }

}
