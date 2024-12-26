// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWorldID} from "./interfaces/IWorldID.sol";
import "./interfaces/IEventNFT.sol";
import "./interfaces/IEventRewardManager.sol";

contract EventManager {
    ////////////////////////////////////////////////////////////////
    ///                      CONFIG STORAGE                      ///
    ////////////////////////////////////////////////////////////////

    IWorldID internal immutable worldId;

    enum RewardType {
        NONE,
        TOKEN,
        NFT
    }

    enum TokenType {
        NONE,
        USDC,
        WLD,
        NFT
    }

    struct Event {
        uint256 id;
        string description;
        string name;
        uint256 timestamp;
        RewardType rewardType;
        address creator;
        address[] participants;
    }

    IEventRewardManager public rewardContract;
    IEventNFT public eventNFt;
    string public appId;
    string public actionId;
    address public owner;
    uint256 internal groupId;
    uint256 internal immutable externalNullifier;

    event ParticipantRegistered(uint256 eventId, address indexed participant);
    event MerkleRootGenerated(uint256 eventId, bytes32 merkleRoot);

    mapping(uint256 => mapping(address => bool)) private registeredParticipants;
    mapping(uint256 => Event) private events;
    uint256[] private eventIds;
    uint256 private nextEventId;
    mapping(uint256 => bool) private nullifierHashes;
    uint256 public worldIdRoot;

    event ParticipantRewardSet(
        uint256 indexed eventId,
        address indexed participant,
        address indexed tokenAddress,
        uint256 amount
    );
    event BulkTokenRewardSet(
        uint256 indexed eventId,
        address[] indexed recipients,
        uint256[] amounts
    );

    ////////////////////////////////////////////////////////////////
    ///                       CONSTRUCTOR                        ///
    ////////////////////////////////////////////////////////////////

    constructor(
        address _worldId,
        uint256 _root,
        string memory _appId,
        string memory _actionId,
        uint256 _groupId,
        address _eventNFTAdd
    ) {
        eventNFt = IEventNFT(_eventNFTAdd);
        worldId = IWorldID(_worldId);
        appId = _appId;
        actionId = _actionId;
        worldIdRoot = _root;
        owner = msg.sender;
        groupId = _groupId;
        externalNullifier = abi.encodePacked(_appId, _actionId).hashToField();
    }

    modifier onlyOwner() {
        require(owner == msg.sender, "Not Owner");
        _;
    }

    modifier onlyEventManager(uint256 _eventId) {
        Event memory ev = events[_eventId];
        require(msg.sender == ev.creator, "Not event manager");
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

    function setRewardContract(address _rewardContract) external onlyOwner {
        require(
            address(rewardContract) == address(0),
            "Reward contract already set"
        );
        require(
            _rewardContract != address(0),
            "Invalid reward contract address"
        );

        rewardContract = IEventRewardManager(_rewardContract);
    }

    /// @dev Register a participant for an existing event after World ID verification.
    function registerParticipant(
        uint256 eventId,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) public {
        require(eventId < nextEventId, "Event does not exist");
        require(
            !registeredParticipants[eventId][msg.sender],
            "Already registered as participant"
        );
        require(
            !nullifierHashes[nullifierHash],
            "World ID verification already used"
        );

        // We now verify the provided proof is valid and the user is verified by World ID
        worldId.verifyProof(
            worldIdRoot,
            groupId,
            abi.encodePacked(msg.sender).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        events[eventId].participants.push(msg.sender);
        registeredParticipants[eventId][msg.sender] = true;
        nullifierHashes[nullifierHash] = true;

        emit ParticipantRegistered(eventId, msg.sender);
    }

    /// @dev Create a new event
    function createEvent(
        string memory name,
        string memory description,
        uint256 timestamp,
        address _tokenAddress,
        RewardType _rewardType,
        TokenType _rewardToken,
        uint256 _rewardAmount
    ) public {
        require(bytes(name).length > 0, "Event name is required");
        require(bytes(description).length > 0, "Description is required");
        require(timestamp > block.timestamp, "Timestamp must be in the future");
        require(_tokenAddress != address(0), "Invalid token address");
        require(_rewardAmount > 0, "Invalid token amount");

        if (_rewardType == RewardType.TOKEN) {
            require(
                _rewardToken == TokenType.USDC || _rewardToken == TokenType.WLD,
                "Invalid token type"
            );

            events[nextEventId] = Event({
                id: nextEventId,
                name: name,
                description: description,
                timestamp: timestamp,
                rewardType: _rewardType,
                creator: msg.sender,
                participants: new address[](0)
            });

            eventIds.push(nextEventId);

            IEventRewardManager.TokenType rewardTokenType = IEventRewardManager
                .TokenType(uint256(_rewardToken));

            rewardContract.createTokenReward(
                nextEventId,
                rewardTokenType,
                _tokenAddress,
                _rewardAmount,
                msg.sender
            );
        }

        nextEventId++;
    }

    function updateEventTokenReward(
        uint256 _eventId,
        uint256 _amount
    ) external onlyEventManager(_eventId) {
        checkZeroAddress();

        checkEventIsValid(_eventId);

        require(msg.sender != address(0), "Address zero detected.");

        Event memory ev = events[_eventId];

        rewardContract.updateTokenReward(msg.sender, _eventId, _amount);

        //Emit Event Here
    }

    /// @dev Retrieve an event by its ID
    function getEvent(uint256 id) public view returns (Event memory) {
        if (events[id].id != id) {
            revert("Event does not exist");
        }
        return events[id];
    }

    /// @dev Retrieve all events
    function getAllEvents() public view returns (Event[] memory) {
        Event[] memory allEvents = new Event[](eventIds.length);
        for (uint256 i = 0; i < eventIds.length; i++) {
            allEvents[i] = events[eventIds[i]];
        }
        return allEvents;
    }

    /// @dev Distribute token reward to a participant
    function setTokenRewardForParticipant(
        uint256 eventId,
        address _participant,
        uint256 _reward
    ) external onlyEventManager(eventId) {
        require(
            registeredParticipants[eventId][_participant],
            "Invalid participant."
        );
        require(_reward > 0, "Invalid reward amount");

        Event memory ev = events[eventId];

        rewardContract.distributeTokenReward(eventId, _participant, _reward);

        emit ParticipantRewardSet(eventId, _participant, ev.creator, _reward);
    }

    /// @dev Distribute bulk rewards
    function setBulkRewardsForParticipants(
        uint256 eventId,
        address[] calldata _participants,
        uint256[] calldata _rewards
    ) external onlyEventManager(eventId) {
        require(
            _participants.length == _rewards.length,
            "Array lengths must match"
        );

        rewardContract.distributeMultipleTokenRewards(
            eventId,
            _participants,
            _rewards
        );

        emit BulkTokenRewardSet(eventId, _participants, _rewards);
    }

    /// @dev Claim token reward
    function claimReward(
        uint256 eventId,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external {
        require(msg.sender != address(0), "Invalid address");
        require(
            registeredParticipants[eventId][msg.sender],
            "Not registered for event"
        );

        checkEventIsValid(eventId);

        worldId.verifyProof(
            worldIdRoot,
            groupId,
            abi.encodePacked(msg.sender).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        rewardContract.claimTokenReward(eventId, msg.sender);
    }

    function claimNFTReward(
        uint256 eventId,
        uint256 nullifierHash,
        uint256[8] calldata proof
    ) external {
        require(msg.sender != address(0), "Invalid address");
        require(
            registeredParticipants[eventId][msg.sender],
            "Not registered for event"
        );

        checkEventIsValid(eventId);

        worldId.verifyProof(
            worldIdRoot,
            groupId,
            abi.encodePacked(msg.sender).hashToField(),
            nullifierHash,
            externalNullifier,
            proof
        );

        eventNFt.claimNFTWithZk(msg.sender);
    }
}
