// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IEventNFT {
  function setMerkleRoot(bytes32 _merkleRoot) external;

  function setEventContract(address _eventContract) external;

  function claimNFT(address participant, bytes32[] calldata proof) external;

  function setBaseURI(string memory baseURI) external;

  function supportsInterface(bytes4 interfaceId) external view returns (bool);

  // View functions
  function maxSupply() external view returns (uint256);

  function eventContract() external view returns (address);

  function merkleRoot() external view returns (bytes32);

  function claimed(address participant) external view returns (bool);

  function claimNFTWithZk(address participant) external;
}
