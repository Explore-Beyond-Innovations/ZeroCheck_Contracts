//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IWorldID {
  function verifyProof(uint256, address, bytes calldata) external returns (bool);
}
