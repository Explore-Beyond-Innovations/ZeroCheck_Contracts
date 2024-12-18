//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IWorldID {
  // function verifyProof(
  //     uint256,
  //     address,
  //     bytes calldata
  // ) external returns (bool);
  function verifyProof(
    uint256 root,
    uint256 nullifierHash,
    address user,
    string memory appId,
    string memory actionId,
    uint256[8] memory proof
  )
    external
    view
    returns (bool);
}
