// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IWorldID } from "./interfaces/IWorldID.sol";
import { Merkle } from "murky/src/Merkle.sol";
import "./EventRewardManager.sol";
import { ByteHasher } from "./helpers/ByteHasher.sol";
import { IEventManager } from "./interfaces/IEventManager.sol";
import { IEventRewardManager } from "./interfaces/IEventRewardManager.sol";

using ByteHasher for bytes;

contract EventManager is Ownable, IEventManager {
  ////////////////////////////////////////////////////////////////
  ///                      CONFIG STORAGE                      ///
  ////////////////////////////////////////////////////////////////
  /// @dev The address of the World ID Router contract that will be used for verifying proofs
  IWorldID internal immutable worldId;
  IEventRewardManager public rewardManager;

  string public appId;
  string public actionId;
  uint256 internal groupId;
  uint256 internal immutable externalNullifier;

  mapping(uint256 => mapping(address => bool)) private registeredParticipants;

  mapping(uint256 => Event) private events;
  uint256[] private eventIds;
  uint256 private nextEventId;

  mapping(uint256 => bool) private nullifierHashes;

  uint256 public worldIdRoot;

  struct Event {
    uint256 id;
    string description;
    string name;
    uint256 timestamp;
    address creator;
    address[] participants;
    bytes32 merkleRoot;
    bool rewardSet;
    bool isEnded;
  }

  event EventRegistered(uint256 id, string description, address indexed creator);
  event ParticipantRegistered(uint256 eventId, address indexed participant);
  event MerkleRootGenerated(uint256 eventId, bytes32 merkleRoot);
  event ParticipantRewardSet(
    uint256 indexed eventId,
    address indexed participant,
    address indexed tokenAddress,
    uint256 amount
  );
  event BulkTokenRewardSet(
    uint256 indexed eventId, address[] indexed recipients, uint256[] amounts
  );
  event FirstParticpantBonusSet(
    uint256 indexed eventId, address indexed participant, uint256 bonus
  );
  event EventClosed(uint256 indexed eventId, bool closed);

  ////////////////////////////////////////////////////////////////
  ///                       CONSTRUCTOR                        ///
  ////////////////////////////////////////////////////////////////

  /// @param _worldId The address of the WorldIDRouter that will verify the proofs
  /// @param _appId The World ID App ID (from Developer Portal)
  /// @param _actionId The World ID Action (from Developer Portal)
  constructor(
    address _worldId,
    uint256 _root,
    string memory _appId,
    string memory _actionId,
    uint256 _groupId
  )
    Ownable(msg.sender)
  {
    worldId = IWorldID(_worldId);
    appId = _appId;
    actionId = _actionId;
    worldIdRoot = _root;
    groupId = _groupId;
    externalNullifier = abi.encodePacked(_appId, _actionId).hashToField();
  }

  modifier onlyEventCreator(uint256 _eventId) {
    require(msg.sender == events[_eventId].creator, "EventManager: Only event creator");
    _;
  }

  modifier isNotEnded(uint256 _eventId) {
    Event memory ev = events[_eventId];
    require(!ev.isEnded, "Event Has Ended.");
    _;
  }

  function checkZeroAddress() internal view {
    if (msg.sender == address(0)) revert("Zero address detected!");
  }

  function checkEventIsValid(uint256 _eventId) internal view {
    if (events[_eventId].creator == address(0x0)) {
      revert("Event does not exist");
    }
  }

  ////////////////////////////////////////////////////////////////
  ///                        FUNCTIONS                         ///
  ////////////////////////////////////////////////////////////////

  // Set Event Manager

  function setRewardManager(address _rewardManagerAddress) public onlyOwner {
    require(_rewardManagerAddress != address(0), "Invalid reward contract address");
    rewardManager = IEventRewardManager(_rewardManagerAddress);
  }

  // Create Events Function
  function createEvent(string memory name, string memory description, uint256 timestamp) public {
    // Validation checks
    require(bytes(name).length > 0, "Event name is required");
    require(bytes(description).length > 0, "Description is required");
    require(timestamp > block.timestamp, "Timestamp must be in the future");

    // Create and store the event in the mapping
    events[nextEventId] = Event({
      id: nextEventId,
      name: name,
      description: description,
      timestamp: timestamp,
      creator: msg.sender,
      participants: new address[](0),
      merkleRoot: bytes32(0),
      rewardSet: false,
      isEnded: false
    });

    eventIds.push(nextEventId);
    nextEventId++;

    emit EventRegistered(nextEventId, description, msg.sender);
  }

  /// @dev Close an Event
  function closeEvent(uint256 _eventId) external onlyEventCreator(_eventId) {
    checkEventIsValid(_eventId);

    Event storage ev = events[_eventId];
    ev.isEnded = true;

    emit EventClosed(_eventId, true);
  }

  /// @dev Register a participant for an existing event after World ID verification.
  /// @param eventId The ID of the event to register for.
  /// @param nullifierHash The nullifier hash provided by World ID to prevent double registration.
  /// @param proof The zk-proof for verification.
  function registerParticipant(
    uint256 eventId,
    uint256 nullifierHash,
    uint256[8] calldata proof
  )
    public
    isNotEnded(eventId)
  {
    require(eventId < nextEventId, "Event does not exist");
    require(!registeredParticipants[eventId][msg.sender], "Already registered as participant");
    require(!nullifierHashes[nullifierHash], "World ID verification already used");

    _verifyProof(nullifierHash, proof);

    events[eventId].participants.push(msg.sender);
    registeredParticipants[eventId][msg.sender] = true;

    nullifierHashes[nullifierHash] = true;

    emit ParticipantRegistered(eventId, msg.sender);
  }

  function createReward(
    uint256 _eventId,
    string memory _tokenName,
    string memory _tokenSymbol,
    uint256 _maxSupply,
    string memory _baseURI,
    EventRewardManager.TokenType _tokenType,
    address _tokenAddress,
    uint256 _rewardAmount,
    string memory _BonusbaseURI
  )
    external
    onlyEventCreator(_eventId)
  {
    require(address(rewardManager) != address(0), "Reward manager not set");
    if (_tokenType == IEventRewardManager.TokenType.NFT) {
      rewardManager.createNFTReward(
        _eventId,
        msg.sender,
        _tokenType,
        _tokenName,
        _tokenSymbol,
        _maxSupply,
        _baseURI,
        _BonusbaseURI
      );
    } else {
      rewardManager.createTokenReward(
        _eventId, msg.sender, _tokenType, _tokenAddress, _rewardAmount
      );
    }

    events[_eventId].rewardSet = true;
  }

  function updateEventTokenReward(
    uint256 _eventId,
    uint256 _amount
  )
    external
    onlyEventCreator(_eventId)
    isNotEnded(_eventId)
  {
    checkZeroAddress();

    checkEventIsValid(_eventId);

    require(msg.sender != address(0), "Address zero detected.");

    rewardManager.updateTokenReward(_eventId, msg.sender, _amount);

    //Emit Event Here
  }

  // Retrieve an event by its ID

  function getEvent(uint256 id) public view returns (Event memory) {
    if (events[id].id != id) {
      revert("Event does not exist");
    }
    return events[id];
  }

  // Retrieve all events
  function getAllEvents() public view returns (Event[] memory) {
    Event[] memory allEvents = new Event[](eventIds.length);
    for (uint256 i = 0; i < eventIds.length; i++) {
      allEvents[i] = events[eventIds[i]];
    }
    return allEvents;
  }

  function getWorldId() public view returns (IWorldID) {
    return worldId;
  }

  /// @dev Distribute token reward to a participant
  function setTokenRewardForParticipant(
    uint256 eventId,
    address _participant,
    uint256 _reward
  )
    external
    onlyEventCreator(eventId)
  {
    require(registeredParticipants[eventId][_participant], "Invalid participant.");
    require(_reward > 0, "Invalid reward amount");

    Event memory ev = events[eventId];

    rewardManager.distributeTokenReward(eventId, msg.sender, _participant, _reward);

    emit ParticipantRewardSet(eventId, _participant, ev.creator, _reward);
  }

  /// @dev Distribute bulk rewards
  function setBulkRewardsForParticipants(
    uint256 eventId,
    address[] calldata _participants,
    uint256[] calldata _rewards
  )
    external
    onlyEventCreator(eventId)
  {
    require(_participants.length == _rewards.length, "Array lengths must match");

    rewardManager.distributeMultipleTokenRewards(eventId, msg.sender, _participants, _rewards);

    emit BulkTokenRewardSet(eventId, _participants, _rewards);
  }

  /// @dev Claim token reward
  function claimReward(
    uint256 eventId,
    uint256 nullifierHash,
    uint256[8] calldata proof
  )
    external
    isNotEnded(eventId)
  {
    require(msg.sender != address(0), "Invalid address");
    require(registeredParticipants[eventId][msg.sender], "Not registered for event");
    require(nullifierHashes[nullifierHash], "World ID verification not found");

    checkEventIsValid(eventId);

    _verifyProof(nullifierHash, proof);

    rewardManager.claimTokenReward(eventId, msg.sender);
  }

  function claimNFTReward(
    uint256 eventId,
    uint256 nullifierHash,
    uint256[8] calldata proof
  )
    external
    isNotEnded(eventId)
  {
    require(msg.sender != address(0), "Invalid address");
    require(registeredParticipants[eventId][msg.sender], "Not registered for event");

    Event memory ev = events[eventId];
    require(ev.creator != address(0), "Address zero detected");

    checkEventIsValid(eventId);

    _verifyProof(nullifierHash, proof);

    rewardManager.claimNFTReward(eventId, msg.sender);
  }

  // Helper Function 1: Proof Verification
  function _verifyProof(uint256 nullifierHash, uint256[8] calldata proof) internal view {
    worldId.verifyProof(
      worldIdRoot,
      groupId,
      abi.encodePacked(msg.sender).hashToField(),
      nullifierHash,
      externalNullifier,
      proof
    );
  }
}
