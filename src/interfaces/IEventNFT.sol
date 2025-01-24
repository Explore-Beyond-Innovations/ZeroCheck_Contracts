// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IEventNFT {
  function setEventManager(address _eventContract) external;

  function setBaseURI(string memory baseURI) external;

  function setBonusURI(string memory baseURI) external;

  function claimNFT(address participant) external returns (uint256);

  function mintBonusNFT(address participant) external returns (uint256);

  // View functions
  function hasClaimedNFT(address participant) external view returns (bool);
  function hasClaimedBonusNFT(address participant) external view returns (bool);
}
