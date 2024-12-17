// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IWorldID {
  function verifyProof(
    uint256 root,
    uint256 nullifierHash,
    uint256[8] calldata proof
  )
    external
    view;
}
