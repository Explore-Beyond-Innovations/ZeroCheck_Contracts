// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import { IEventNFT } from "./interfaces/IEventNFT.sol";
import { IEventManager } from "./interfaces/IEventManager.sol";
import { IEventRewardManager } from "./interfaces/IEventRewardManager.sol";
import "./EventManager.sol";
import "./EventNFT.sol";

contract EventRewardManager is Ownable, IEventRewardManager {
  EventManager public eventManager;

  struct TokenReward {
    address eventCreator;
    address tokenAddress;
    TokenType tokenType;
    uint256 rewardAmount;
    uint256 createdAt;
    bool isCancelled;
    uint256 claimedAmount;
  }

  event RewardCreated(
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

  event TokenRewardBonusDistributed(
    uint256 indexed eventId, address indexed recipient, uint256 bonus
  );

  event MultipleTokenRewardDistributed(
    uint256 indexed eventId, address[] indexed recipients, uint256[] amounts
  );

  event TokenRewardClaimed(uint256 indexed eventId, address indexed recipient, uint256 amount);

  event NFTRewardClaimed(uint256 indexed eventId, address indexed recipient, uint256 tokenId);

  event BonusRewardClaimed(uint256 indexed eventId, address indexed recipient, uint256 tokenId);

  mapping(uint256 => TokenReward) public eventTokenRewards;
  mapping(uint256 => mapping(address => uint256)) public userTokenRewards;
  mapping(uint256 => mapping(address => bool)) public hasClaimedTokenReward;

  //Minimum wait time required before the unclaimed reward withdrawal operation can be performed
  uint256 public constant WITHDRAWAL_TIMEOUT = 30 days;

  constructor(address _eventManagerAddress) Ownable(msg.sender) {
    eventManager = EventManager(_eventManagerAddress);
  }

  modifier checkEventCreator(uint256 _eventId, address _caller) {
    EventManager.Event memory ev = eventManager.getEvent(_eventId);
    require(_caller == ev.creator, "Not event creator");
    _;
  }

  modifier onlyEventContract() {
    require(msg.sender == address(eventManager), "Only event manager allowed");
    _;
  }

  function checkZeroAddress() internal view {
    if (msg.sender == address(0)) revert("Zero address detected!");
  }

  function checkEventIsValid(uint256 _eventId) internal view {
    if (eventManager.getEvent(_eventId).creator == address(0x0)) {
      revert("Event does not exist");
    }
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
    external
    onlyEventContract
    checkEventCreator(_eventId, creator)
  {
    checkZeroAddress();
    checkEventIsValid(_eventId);

    if (_tokenType != TokenType.NFT) {
      revert("Invalid token type");
    }

    EventNFT nft =
      new EventNFT(_name, _symbol, _maxSupply, _baseURI, _BonusbaseURI, address(eventManager));

    eventTokenRewards[_eventId] = TokenReward({
      eventCreator: creator,
      tokenAddress: address(nft),
      tokenType: _tokenType,
      rewardAmount: 1,
      claimedAmount: 0, // Initialize claimed amount to 0
      createdAt: block.timestamp,
      isCancelled: false
    });

    emit RewardCreated(_eventId, creator, address(nft), _tokenType, 1);
  }

  // Create token-based event rewards
  function createTokenReward(
    uint256 _eventId,
    address creator,
    TokenType _tokenType,
    address _tokenAddress,
    uint256 _rewardAmount
  )
    external
    onlyEventContract
    checkEventCreator(_eventId, creator)
  {
    checkZeroAddress();

    checkEventIsValid(_eventId);

    if (_tokenAddress == address(0)) revert("Zero token address detected");

    if (_rewardAmount == 0) revert("Zero amount detected");

    if (_tokenType != TokenType.USDC && _tokenType != TokenType.WLD) {
      revert("Invalid token type");
    }

    eventTokenRewards[_eventId] = TokenReward({
      eventCreator: creator,
      tokenAddress: _tokenAddress,
      tokenType: _tokenType,
      rewardAmount: _rewardAmount,
      claimedAmount: 0, // Initialize claimed amount to 0
      createdAt: block.timestamp,
      isCancelled: false
    });

    // Transfer tokens from event manager to contract
    IERC20 token = IERC20(_tokenAddress);
    require(token.transferFrom(creator, address(this), _rewardAmount), "Token transfer failed");

    emit RewardCreated(_eventId, creator, _tokenAddress, _tokenType, _rewardAmount);
  }

  // Update token-based event reward amount
  function updateTokenReward(
    uint256 _eventId,
    address creator,
    uint256 _amount
  )
    external
    onlyEventContract
    checkEventCreator(_eventId, creator)
  {
    checkZeroAddress();

    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (eventReward.tokenType != TokenType.USDC && eventReward.tokenType != TokenType.WLD) {
      revert("Invalid token type");
    }

    eventReward.rewardAmount += _amount;

    IERC20 token = IERC20(eventReward.tokenAddress);
    require(token.transferFrom(creator, address(this), _amount), "Token transfer failed");

    emit TokenRewardUpdated(_eventId, creator, _amount);
  }

  // Function to distribute tokens to event participants
  function distributeTokenReward(
    uint256 _eventId,
    address _creator,
    address _recipient,
    uint256 _participantReward
  )
    external
    onlyEventContract
    checkEventCreator(_eventId, _creator)
  {
    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (eventReward.tokenType != TokenType.USDC && eventReward.tokenType == TokenType.WLD) {
      revert("No event token reward");
    }

    if (_participantReward > eventReward.rewardAmount - eventReward.claimedAmount) {
      revert("Insufficient reward amount");
    }

    eventReward.rewardAmount -= _participantReward;
    userTokenRewards[_eventId][_recipient] += _participantReward;

    emit TokenRewardDistributed(_eventId, _recipient, _participantReward);
  }

  function distributeMultipleTokenRewards(
    uint256 _eventId,
    address _creator,
    address[] calldata _recipients,
    uint256[] calldata _participantRewards
  )
    external
    onlyEventContract
    checkEventCreator(_eventId, _creator)
  {
    checkEventIsValid(_eventId);
    require(_recipients.length == _participantRewards.length, "Arrays length mismatch");
    require(_recipients.length > 0, "Empty arrays");

    TokenReward storage eventReward = eventTokenRewards[_eventId];
    require(
      eventReward.tokenType == TokenType.USDC || eventReward.tokenType == TokenType.WLD,
      "Invalid token type"
    );

    uint256 length = _recipients.length;
    uint256 totalRewardAmount;

    for (uint256 i; i < length;) {
      totalRewardAmount += _participantRewards[i];
      unchecked {
        i++;
      }
    }

    require(totalRewardAmount <= eventReward.rewardAmount, "Insufficient reward amount");

    for (uint256 i; i < length;) {
      require(_recipients[i] != address(0), "Invalid recipient address");
      require(_participantRewards[i] > 0, "Invalid reward amount");

      eventReward.rewardAmount -= _participantRewards[i];
      userTokenRewards[_eventId][_recipients[i]] += _participantRewards[i];

      unchecked {
        i++;
      }
    }

    emit MultipleTokenRewardDistributed(_eventId, _recipients, _participantRewards);
  }

  function getUserTokenReward(uint256 _eventId, address _user) external view returns (uint256) {
    checkEventIsValid(_eventId);

    require(_user != address(0), "Zero Address Detected");

    return userTokenRewards[_eventId][_user];
  }

  function getMultipleDistributedTokenRewards(
    uint256 _eventId,
    address[] calldata _participants
  )
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory rewards = new uint256[](_participants.length);
    for (uint256 i = 0; i < _participants.length; i++) {
      rewards[i] = userTokenRewards[_eventId][_participants[i]];
    }
    return rewards;
  }

  //Distribute particpant bonus token for first Participant of the event
  function setFirstParticipantTokenBonus(
    uint256 _eventId,
    address _eventCreator,
    address _recipient,
    uint256 _bonus
  )
    external
    checkEventCreator(_eventId, _eventCreator)
  {
    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (eventReward.tokenType != TokenType.USDC && eventReward.tokenType == TokenType.WLD) {
      revert("No event token reward");
    }

    if (_bonus > eventReward.rewardAmount - eventReward.claimedAmount) {
      revert("Insufficient reward amount");
    }

    eventReward.rewardAmount -= _bonus;
    userTokenRewards[_eventId][_recipient] += _bonus;

    emit TokenRewardBonusDistributed(_eventId, _recipient, _bonus);
  }

  function claimTokenReward(uint256 _eventId, address participant) external onlyEventContract {
    checkEventIsValid(_eventId);

    EventManager.Event memory event_ = eventManager.getEvent(_eventId);
    bool isParticipant = false;
    for (uint256 i = 0; i < event_.participants.length; i++) {
      if (event_.participants[i] == participant) {
        isParticipant = true;
        break;
      }
    }
    require(isParticipant, "Not a registered participant");

    uint256 rewardAmount = userTokenRewards[_eventId][participant];
    require(rewardAmount > 0, "No reward to claim");
    require(!hasClaimedTokenReward[_eventId][participant], "Reward already claimed");

    TokenReward storage eventReward = eventTokenRewards[_eventId];
    require(eventReward.tokenAddress != address(0), "Invalid token address");

    userTokenRewards[_eventId][participant] = 0;
    hasClaimedTokenReward[_eventId][participant] = true;

    eventReward.claimedAmount += rewardAmount;

    // Transfer tokens to participant
    IERC20 token = IERC20(eventReward.tokenAddress);
    require(token.transfer(participant, rewardAmount), "Token transfer failed");

    emit TokenRewardClaimed(_eventId, participant, rewardAmount);
  }

  function claimNFTReward(uint256 _eventId, address participant) external onlyEventContract {
    checkEventIsValid(_eventId);

    EventManager.Event memory ev = eventManager.getEvent(_eventId);
    bool isParticipant = false;
    for (uint256 i = 0; i < ev.participants.length; i++) {
      if (ev.participants[i] == participant) {
        isParticipant = true;
        break;
      }
    }
    require(isParticipant, "Not a registered participant");

    TokenReward storage eventReward = eventTokenRewards[_eventId];
    require(eventReward.tokenAddress != address(0), "Invalid token address");

    IEventNFT nft = IEventNFT(eventReward.tokenAddress);

    uint256 tokenId = nft.claimNFT(participant);

    // Check if the sender is the first participant and mint bonus NFT
    if (ev.participants.length > 0 && ev.participants[0] == msg.sender) {
      uint256 bonusTokenId = nft.mintBonusNFT(msg.sender);
      emit BonusRewardClaimed(_eventId, participant, bonusTokenId);
    }

    emit NFTRewardClaimed(_eventId, msg.sender, tokenId);
  }

  // Function to withdraw unclaimed rewards after timeout period and cancel the event reward, if the
  // reward have been claimed
  function withdrawUnclaimedRewards(
    uint256 _eventId,
    address creator
  )
    external
    onlyEventContract
    checkEventCreator(_eventId, creator)
  {
    checkZeroAddress();
    checkEventIsValid(_eventId);

    TokenReward storage eventReward = eventTokenRewards[_eventId];

    if (block.timestamp < eventReward.createdAt + WITHDRAWAL_TIMEOUT) {
      revert("Withdrawal timeout not reached");
    }

    if (eventReward.isCancelled) {
      revert("Event reward already cancelled");
    }

    uint256 remainingReward = eventReward.rewardAmount - eventReward.claimedAmount;
    bool cancelled = false;

    // If no rewards have been claimed, cancel the event reward
    if (eventReward.claimedAmount == 0) {
      eventReward.isCancelled = true;
      cancelled = true;
      eventReward.rewardAmount = 0;
    } else {
      eventReward.rewardAmount = eventReward.claimedAmount;
    }

    IERC20 token = IERC20(eventReward.tokenAddress);
    require(token.transfer(msg.sender, remainingReward), "Token withdrawal failed");

    emit TokenRewardWithdrawn(_eventId, msg.sender, remainingReward, cancelled);
  }
}
