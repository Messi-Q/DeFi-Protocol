// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.5.17;

contract EtherRejecter {
  function() payable external {
    revert('I secretly hate ether');
  }
}
