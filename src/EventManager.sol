// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IWorldID } from "./interfaces/IWorldID.sol";
import { Merkle } from "murky/src/Merkle.sol";
import "./EventNFTFactory.sol";
import "./EventRewardManager.sol";

contract EventManager {
  ////////////////////////////////////////////////////////////////
  ///                      CONFIG STORAGE                      ///
  ////////////////////////////////////////////////////////////////
  /// @dev The address of the World ID Router contract that will be used for verifying proofs
  IWorldID internal immutable worldId;
  EventNFTFactory public nftFactory;
  EventRewardManager public rewardManager;
  // address public worldID;

  struct Event {
    uint256 id;
    string description;
    string name;
    uint256 timestamp;
    string rewardType;
    address creator;
    address[] participants;
    bytes32 merkleRoot;
  }

  address public rewardContract;
  string public appId;
  string public actionId;

  struct EventReward {
    address nftAddress;
    uint256 tokenRewardAmount;
    address tokenAddress;
    EventRewardManager.TokenType rewardType;
    bool isActive;
  }
    
   
    
  event RewardCreated( uint256 indexed eventId, address indexed nftAddress, address tokenAddress, EventRewardManager.TokenType rewardType, uint256 rewardAmount);
  event ParticipantRegistered(uint256 eventId, address indexed participant);
  event MerkleRootGenerated(uint256 eventId, bytes32 merkleRoot);

  mapping(uint256 => mapping(address => bool)) private registeredParticipants;
   mapping(uint256 => EventReward) public eventRewards;

  mapping(uint256 => Event) private events;
  uint256[] private eventIds;
  uint256 private nextEventId;

  mapping(uint256 => bool) private nullifierHashes;

  uint256 public worldIdRoot;

  ////////////////////////////////////////////////////////////////
  ///                       CONSTRUCTOR                        ///
  ////////////////////////////////////////////////////////////////

  /// @param _worldId The address of the WorldIDRouter that will verify the proofs
  /// @param _appId The World ID App ID (from Developer Portal)
  /// @param _actionId The World ID Action (from Developer Portal)
  constructor(
    address _worldId,
    uint256 _root,
    address _rewardContract,
    string memory _appId,
    string memory _actionId, 
    address _nftFactoryAddress,
    address _rewardManagerAddress
  ) {
    worldId = IWorldID(_worldId);
    rewardContract = _rewardContract;
    appId = _appId;
    actionId = _actionId;
    worldIdRoot = _root;
    nftFactory = EventNFTFactory(_nftFactoryAddress);
    rewardManager = EventRewardManager(_rewardManagerAddress);
  }

  ////////////////////////////////////////////////////////////////
  ///                        FUNCTIONS                         ///
  ////////////////////////////////////////////////////////////////

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
  {
    require(eventId < nextEventId, "Event does not exist");
    require(!registeredParticipants[eventId][msg.sender], "Already registered as participant");
    require(!nullifierHashes[nullifierHash], "World ID verification already used");

    worldId.verifyProof(worldIdRoot, nullifierHash, proof);

    events[eventId].participants.push(msg.sender);
    registeredParticipants[eventId][msg.sender] = true;

    nullifierHashes[nullifierHash] = true;

    emit ParticipantRegistered(eventId, msg.sender);
  }

  // Create Events Function
  function createEvent(
    string memory name,
    string memory description,
    uint256 timestamp,
    string memory rewardType
  )
    public
  {
    // Validation checks
    require(bytes(name).length > 0, "Event name is required");
    require(bytes(description).length > 0, "Description is required");
    require(timestamp > block.timestamp, "Timestamp must be in the future");
    require(bytes(rewardType).length > 0, "Reward type is required");

    // Create and store the event in the mapping
    events[nextEventId] = Event({
      id: nextEventId,
      name: name,
      description: description,
      timestamp: timestamp,
      rewardType: rewardType,
      creator: msg.sender,
      participants: new address[](0),
      merkleRoot: bytes32(0)
    });

    eventIds.push(nextEventId);
    nextEventId++;
  }

// Function to create a reward
  function createReward(
        uint256 _eventId,
        string memory _nftName,
        string memory _nftSymbol,
        uint256 _maxSupply,
        string memory _baseURI,
        EventRewardManager.TokenType _tokenType,
        address _tokenAddress,
        uint256 _rewardAmount
    ) external returns (address nftAddress) {
        // Check if reward already exists for this event
        require(!eventRewards[_eventId].isActive, "Reward already exists for this event");
        
        // Create NFT contract through factory
        (EventNFT newNFT, ) = nftFactory.createEventNFT(
            _nftName,
            _nftSymbol,
            _maxSupply,
            _baseURI,
            address(this)
        );
        
        // Create token reward through reward manager
        if (_tokenType != EventRewardManager.TokenType.NONE) {
            rewardManager.createTokenReward(
                _eventId,
                _tokenType,
                _tokenAddress,
                _rewardAmount
            );
        }
        
        // Store reward information
        eventRewards[_eventId] = EventReward({
            nftAddress: address(newNFT),
            tokenRewardAmount: _rewardAmount,
            tokenAddress: _tokenAddress,
            rewardType: _tokenType,
            isActive: true
        });
        
        emit RewardCreated(
            _eventId,
            address(newNFT),
            _tokenAddress,
            _tokenType,
            _rewardAmount
        );
        
        return address(newNFT);
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
}
