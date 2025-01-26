// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { EventManager } from "../EventManager.sol";

interface IEventRewardManager {
  enum TokenType {
    NONE,
    USDC,
    WLD,
    NFT
  }

  function createNFTReward(
    uint256 _eventId,
    address creator,
    TokenType _tokenType,
    string memory _name,
    string memory _symbol,
    uint256 _maxSupply,
    string memory _baseURI,
    string memory _BonusbaseURI
  )
    external;

  function createTokenReward(
    uint256 _eventId,
    address creator,
    TokenType _tokenType,
    address _tokenAddress,
    uint256 _rewardAmount
  )
    external;

  function updateTokenReward(uint256 _eventId, address eventCreator, uint256 _amount) external;

  function distributeTokenReward(
    uint256 _eventId,
    address _creator,
    address _recipient,
    uint256 _participantReward
  )
    external;

  function distributeMultipleTokenRewards(
    uint256 _eventId,
    address _creator,
    address[] calldata _recipients,
    uint256[] calldata _participantRewards
  )
    external;

  function getUserTokenReward(uint256 _eventId, address _user) external view returns (uint256);

  function getMultipleDistributedTokenRewards(
    uint256 _eventId,
    address[] calldata _participants
  )
    external
    view
    returns (uint256[] memory);

  function setFirstParticipantTokenBonus(
    uint256 _eventId,
    address _eventCreator,
    address _recipient,
    uint256 _bonus
  )
    external;

  function claimTokenReward(uint256 _eventId, address participant) external;

  function claimNFTReward(uint256 _eventId, address participant) external;

  function withdrawUnclaimedRewards(uint256 _eventId, address creator) external;
}
