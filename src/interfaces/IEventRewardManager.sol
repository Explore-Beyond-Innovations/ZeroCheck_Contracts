// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IEventRewardManager {
  enum TokenType {
    NONE,
    USDC,
    WLD,
    NFT
  }

  struct TokenReward {
    address eventManager;
    address tokenAddress;
    TokenType tokenType;
    uint256 rewardAmount;
    uint256 createdAt;
    bool isCancelled;
    uint256 claimedAmount;
  }

  event TokenRewardCreated(
    uint256 indexed eventId,
    address indexed eventManager,
    address tokenAddress,
    TokenType tokenType,
    uint256 indexed rewardAmount
  );

  event TokenRewardUpdated(
    uint256 indexed eventId, address indexed eventManager, uint256 indexed newRewardAmount
  );

  event TokenRewardWithdrawn(
    uint256 indexed eventId, address indexed eventManager, uint256 indexed amount, bool cancelled
  );

  event TokenRewardDistributed(uint256 indexed eventId, address indexed recipient, uint256 amount);

  event MultipleTokenRewardDistributed(
    uint256 indexed eventId, address[] indexed recipients, uint256[] amounts
  );

  event TokenRewardClaimed(uint256 indexed eventId, address indexed recipient, uint256 amount);

  function createTokenReward(
    uint256 _eventId,
    TokenType _tokenType,
    address _tokenAddress,
    uint256 _rewardAmount,
    address _creator
  )
    external;

  function updateTokenReward(uint256 _eventId, uint256 _amount) external;

  function distributeTokenReward(
    uint256 _eventId,
    address _recipient,
    uint256 _participantReward
  )
    external;

  function distributeMultipleTokenRewards(
    uint256 _eventId,
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

  function claimTokenReward(uint256 _eventId, address _participant) external;

  function withdrawUnclaimedRewards(uint256 _eventId) external;
}
