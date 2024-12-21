// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IWorldID } from "./interfaces/IWorldID.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./interfaces/IEventNFT.sol";

contract EventManager {
  ////////////////////////////////////////////////////////////////
  ///                      CONFIG STORAGE                      ///
  ////////////////////////////////////////////////////////////////
  /// @dev The address of the World ID Router contract that will be used for verifying proofs
  IWorldID internal immutable worldId;
  // address public worldID;

  enum RewardType {
    None,
    TOKEN,
    NFT
  }

  struct Event {
    uint256 id;
    address creator;
    string description;
    string name;
    uint256 timestamp;
    RewardType rewardType;
    uint256 totalParticipant;
    address tokenAddress; //If rewardType is an ERC20 Token
    uint256 amountReward; //Amount Reward for each participant Example: 10DAI for each Participant
    uint256 firstregistrantBonus; //bonus for first registrant.
    uint256 nftBonusId; //Bonus for First time registrant if reward is NFT
    address eventNFT;
  }

  address public rewardContract;
  string public appId;
  string public actionId;

  //  State Variable for Create Events
  uint256 public nextEventId;

  mapping(uint256 => mapping(address => bool)) public isParticipant; //EventId => USer Address =>
  // Bool
  mapping(uint256 => mapping(address => bool)) public hasClaimedReward; //EventId => USer Address =>
  // Bool
  mapping(uint256 => mapping(uint256 => bool)) public nullifierHashes; // eventId => nullifierHash
  // => bool
  mapping(uint256 => address[]) eventParticipant;

  ////////////////////////////////////////////////////////////////
  ///                       CONSTRUCTOR                        ///
  ////////////////////////////////////////////////////////////////

  /// @param _worldId The address of the WorldIDRouter that will verify the proofs
  /// @param _appId The World ID App ID (from Developer Portal)
  /// @param _actionId The World ID Action (from Developer Portal)
  constructor(
    IWorldID _worldId,
    address _rewardContract,
    string memory _appId,
    string memory _actionId
  ) {
    worldId = _worldId;
    rewardContract = _rewardContract;
    appId = _appId;
    actionId = _actionId;
  }

  Event[] public events;

  event RegisteredSuccessful(uint256 indexed eventId, address _addr);

  ////////////////////////////////////////////////////////////////
  ///                        FUNCTIONS                         ///
  ////////////////////////////////////////////////////////////////

  /**
   * @notice Creates a new event with the specified details.
   * @dev Validates inputs such as name, description, timestamp, and reward configuration.
   * @param name The name of the event.
   * @param description A description of the event.
   * @param timestamp The scheduled timestamp of the event (must be in the future).
   * @param _rewardType The type of reward for participants (TOKEN or NFT).
   * @param _tokenAddress The address of the token/NFT contract (required if reward type is TOKEN or
   * NFT).
   * @param _amountReward The amount of ERC20 token reward per participant (if applicable).
   * @param _firstregistrantBonus The bonus reward for the first registrant.
   * @param bonusNft The NFT ID for the bonus reward (if reward is NFT).
   * @param _eventNFT The address of the event-specific NFT contract.
   */
  function createEvent(
    string memory name,
    string memory description,
    uint256 timestamp,
    RewardType _rewardType,
    address _tokenAddress,
    uint256 _amountReward,
    uint256 _firstregistrantBonus,
    uint256 bonusNft,
    address _eventNFT
  )
    public
  {
    // Validation checks
    require(bytes(name).length > 0, "Event name is required");
    require(bytes(description).length > 0, "Description is required");
    require(timestamp > block.timestamp, "Timestamp must be in the future");
    if (_rewardType == RewardType.TOKEN) {
      require(_tokenAddress != address(0), "Enter valid token Address");
    }
    if (_rewardType == RewardType.NFT) {
      require(_tokenAddress != address(0), "Enter valid token Address");
    }

    require(_eventNFT != address(0), "Invalid event NFT contract.");

    // Create the event
    events.push(
      Event({
        id: nextEventId,
        creator: msg.sender,
        name: name,
        description: description,
        timestamp: timestamp,
        rewardType: _rewardType,
        totalParticipant: 0,
        tokenAddress: _tokenAddress,
        amountReward: _amountReward,
        firstregistrantBonus: _firstregistrantBonus,
        nftBonusId: bonusNft,
        eventNFT: _eventNFT
      })
    );

    // Increment the event ID
    nextEventId++;
  }

  /**
   * @notice Fetches the details of an event by its ID.
   * @param id The ID of the event to retrieve.
   * @return Event The event data associated with the given ID.
   */
  function getEvent(uint256 id) public view returns (Event memory) {
    if (id >= events.length) revert("Event does not exist");
    return events[id];
  }

  /**
   * @notice Fetches the list of all events created in the contract.
   * @return Event[] An array containing all event details.
   */
  function getAllEvents() public view returns (Event[] memory) {
    return events;
  }

  /**
   * @notice Adds an event manually for testing purposes.
   * @dev This function is intended for testing scenarios to prepopulate events.
   * @param id The unique ID of the event.
   * @param description A description of the event.
   * @param creator The address of the event creator.
   * @param name The name of the event.
   * @param timestamp The timestamp of the event.
   * @param rewardType The reward type (None, TOKEN, or NFT).
   * @param _tokenAddress The token/NFT contract address.
   * @param _amountReward The amount of ERC20 token reward (if applicable).
   * @param _firstregistrantBonus The bonus for the first registrant.
   * @param bonusNft The NFT ID for the bonus (if applicable).
   * @param _eventNFT The address of the Event NFT contract.
   */
  function addEventForTesting(
    uint256 id,
    string memory description,
    address creator,
    string memory name,
    uint256 timestamp,
    RewardType rewardType,
    address _tokenAddress,
    uint256 _amountReward,
    uint256 _firstregistrantBonus,
    uint256 bonusNft,
    address _eventNFT
  )
    public
  {
    events.push(
      Event({
        id: id,
        description: description,
        creator: creator,
        name: name,
        timestamp: timestamp,
        rewardType: rewardType,
        totalParticipant: 0,
        tokenAddress: _tokenAddress,
        amountReward: _amountReward,
        firstregistrantBonus: _firstregistrantBonus,
        nftBonusId: bonusNft,
        eventNFT: _eventNFT
      })
    );
  }

  /**
   * @notice Fetches the World ID contract address used for verification.
   * @return IWorldID The address of the World ID router contract.
   */
  function getWorldId() public view returns (IWorldID) {
    return worldId;
  }

  /**
   * @notice Allows a user to register for an event using World ID verification.
   * @dev Ensures the event has not started, the user has not already registered,
   * and World ID verification is successful.
   * @param eventId The ID of the event to register for.
   * @param root The root of the World ID Merkle tree.
   * @param nullifierHash The nullifier hash for the user.
   * @param proof The ZKP (Zero-Knowledge Proof) for World ID verification.
   */
  function registerParticipant(
    uint256 eventId,
    uint256 root,
    uint256 nullifierHash,
    uint256[8] memory proof
  )
    public
  {
    Event storage eventData = events[eventId];
    require(eventData.timestamp > block.timestamp, "Event has already started");
    require(!isParticipant[eventId][msg.sender], "Already Registered");

    // Verify the participant using World ID
    worldId.verifyProof(root, nullifierHash, msg.sender, appId, actionId, proof);

    ++eventData.totalParticipant;
    isParticipant[eventId][msg.sender] = true;
    eventParticipant[eventId].push(msg.sender);

    emit RegisteredSuccessful(eventId, msg.sender);
  }

  /**
   * @notice Allows the event creator to set the Merkle root for event NFTs.
   * @dev Only the creator of the event can set the Merkle root.
   * @param eventId The ID of the event for which to set the Merkle root.
   * @param _merkleRoot The new Merkle root to be set in the Event NFT contract.
   */
  function setEventMerkleRoot(uint256 eventId, bytes32 _merkleRoot) external {
    Event storage eventData = events[eventId];
    require(msg.sender == eventData.creator, "Only event creator can set root");
    IEventNFT nftContract = IEventNFT(eventData.eventNFT);
    nftContract.setMerkleRoot(_merkleRoot);
  }

  /**
   * @notice Allows a participant to claim their reward after registering for an event.
   * @dev Supports both ERC20 token rewards and NFT rewards. Ensures the participant
   * has not claimed the reward previously and that their nullifier hash is not reused.
   * @param eventId The ID of the event for which the reward is being claimed.
   * @param nullifierHash The nullifier hash to prevent double claiming.
   * @param proof The Merkle proof required for NFT reward claims.
   */
  function claimReward(uint256 eventId, uint256 nullifierHash, bytes32[] calldata proof) external {
    require(isParticipant[eventId][msg.sender], "Not a participant");
    require(!hasClaimedReward[eventId][msg.sender], "Reward already claimed");
    require(!nullifierHashes[eventId][nullifierHash], "Hash already used");

    Event storage eventData = events[eventId];
    address tokenAddress = eventData.tokenAddress;
    if (eventData.rewardType == RewardType.TOKEN) {
      uint256 totalReward = eventData.amountReward;
      if (msg.sender == eventParticipant[eventData.id][0]) {
        totalReward += eventData.firstregistrantBonus;
      }

      require(
        IERC20(tokenAddress).balanceOf(address(this)) >= totalReward, "Insufficient reward balance"
      );

      IERC20(eventData.tokenAddress).transfer(msg.sender, totalReward);
    }

    if (eventData.rewardType == RewardType.NFT) {
      IEventNFT nftContract = IEventNFT(eventData.eventNFT);
      nftContract.claimNFT(msg.sender, proof);

      // Handle bonus NFT for the first registrant
      if (msg.sender == eventParticipant[eventData.id][0]) {
        require(
          IERC721(eventData.tokenAddress).ownerOf(eventData.nftBonusId) == address(this),
          "Contract does not own the bonus NFT"
        );
        IERC721(tokenAddress).safeTransferFrom(address(this), msg.sender, eventData.nftBonusId);
      }
    }

    hasClaimedReward[eventData.id][msg.sender] = true;
    nullifierHashes[eventId][nullifierHash] = true;
  }
}
