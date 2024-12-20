// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../src/EventManager.sol";

contract EventRewardManager is Ownable {
  EventManager public eventManager;

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
  }

  mapping(uint256 => TokenReward) public eventTokenRewards;

  //Minimum wait time required before the unclaimed reward withdrawal operation can be performed
  uint256 public constant WITHDRAWAL_TIMEOUT = 30 days;

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
    uint256 indexed eventId, address indexed eventManager, uint256 indexed amount
  );

  event TokenRewardCancelled(
    uint256 indexed eventId, address indexed eventManager, uint256 indexed amount
  );

  constructor(address _eventManagerAddress) Ownable(msg.sender) {
    eventManager = EventManager(_eventManagerAddress);
  }

  function checkZeroAddress() internal view {
    if (msg.sender == address(0)) revert("Zero address detected!");
  }

  function checkEventIsValid(uint256 _eventId) internal view {
    if (eventManager.getEvent(_eventId).creator == address(0x0)) {
      revert("Event does not exist");
    }
  }

  // Create token-based event rewards
  function createTokenReward(
    uint256 _eventId,
    TokenType _tokenType,
    address _tokenAddress,
    uint256 _rewardAmount
  )
    external
    onlyOwner
  {
    checkZeroAddress();

    checkEventIsValid(_eventId);

    if (_tokenAddress == address(0)) revert("Zero token address detected");

    if (_rewardAmount == 0) revert("Zero amount detected");

    if (_tokenType != TokenType.USDC && _tokenType != TokenType.WLD) {
      revert("Invalid token type");
    }

    eventTokenRewards[_eventId] = TokenReward({
      eventManager: msg.sender,
      tokenAddress: _tokenAddress,
      tokenType: _tokenType,
      rewardAmount: _rewardAmount,
      createdAt: block.timestamp,
      isCancelled: false
    });

    // Transfer tokens from event manager to contract
    IERC20 token = IERC20(_tokenAddress);
    require(token.transferFrom(msg.sender, address(this), _rewardAmount), "Token transfer failed");

    emit TokenRewardCreated(_eventId, msg.sender, _tokenAddress, _tokenType, _rewardAmount);
  }

  // Update token-based event reward amount
  function updateTokenReward(uint256 _eventId, uint256 _amount) external {
    checkZeroAddress();

    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (eventReward.eventManager != msg.sender) {
      revert("Only event manager allowed");
    }

    eventReward.rewardAmount += _amount;

    IERC20 token = IERC20(eventReward.tokenAddress);
    require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

    emit TokenRewardUpdated(_eventId, msg.sender, _amount);
  }

  // Function to distribute tokens to event participants
  function distributeTokenReward(
    uint256 _eventId,
    address _recipient,
    uint256 _participantReward
  )
    external
    onlyOwner
  {
    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (eventReward.tokenType != TokenType.USDC && eventReward.tokenType == TokenType.WLD) {
      revert("No event token reward");
    }

    if (_participantReward > eventReward.rewardAmount) {
      revert("Insufficient reward amount");
    }

    eventReward.rewardAmount -= _participantReward;

    // Transfer tokens to participant
    IERC20 token = IERC20(eventReward.tokenAddress);
    require(token.transfer(_recipient, _participantReward), "Token distribution failed");
  }

  // Function to withdraw unclaimed rewards after timeout period
  function withdrawUnclaimedRewards(uint256 _eventId) external {
    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (eventReward.eventManager != msg.sender) {
      revert("Only event manager allowed");
    }

    if (block.timestamp < eventReward.createdAt + WITHDRAWAL_TIMEOUT) {
      revert("Withdrawal timeout not reached");
    }

    if (eventReward.isCancelled) {
      revert("Event reward has been cancelled");
    }

    uint256 unclaimedAmount = eventReward.rewardAmount;
    eventReward.rewardAmount = 0;

    IERC20 token = IERC20(eventReward.tokenAddress);
    require(token.transfer(msg.sender, unclaimedAmount), "Token withdrawal failed");

    emit TokenRewardWithdrawn(_eventId, msg.sender, unclaimedAmount);
  }
}
