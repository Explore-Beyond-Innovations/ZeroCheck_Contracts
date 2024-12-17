// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IWorldID} from "./interfaces/IWorldID.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./EventNFT.sol";

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
        uint256 endAt; //Time event closes;
        RewardType rewardType;
        uint256 totalParticipant;
        address tokenAddress; //If rewardType is an ERC20 Token
        uint256 amountReward; //Amount Reward for each participant Example: 10DAI for each Participant
        uint256 firstregistrantBonus; //bonus for first registrant.
        uint256[] nftTokenIds;
        uint256 nftBonusId; //Bonus for First time registrant if reward is NFT
    }

    address public rewardContract;
    string public appId;
    string public actionId;

    //  State Variable for Create Events
    uint256 public nextEventId;
    address eventNftContract;

    mapping(uint256 => mapping(address => bool)) isParticipant; //EventId => USer Address => Bool
    mapping(uint256 => mapping(address => bool)) hasClaimedReward; //EventId => USer Address => Bool
    mapping(uint256 => mapping(uint256 => bool)) public nullifierHashes; // eventId => nullifierHash => bool
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
        string memory _actionId,
        address _eventNftContract
    ) {
        worldId = _worldId;
        rewardContract = _rewardContract;
        appId = _appId;
        actionId = _actionId;
        eventNftContract = _eventNftContract;
    }

    Event[] public events;

    event RegisteredSuccessful(uint256 indexed eventId, address _addr);

    ////////////////////////////////////////////////////////////////
    ///                        FUNCTIONS                         ///
    ////////////////////////////////////////////////////////////////

    // Create Events Function
    function createEvent(
        string memory name,
        string memory description,
        uint256 timestamp,
        uint256 _endAt,
        RewardType _rewardType,
        address _tokenAddress,
        uint256 _amountReward,
        uint256 _firstregistrantBonus,
        uint256[] memory _nftTokenIds,
        uint256 bonusNft
    ) public {
        // Validation checks
        require(bytes(name).length > 0, "Event name is required");
        require(bytes(description).length > 0, "Description is required");
        require(timestamp > block.timestamp, "Timestamp must be in the future");
        require(_endAt > timestamp, "Endat must be greater than timestamp");
        if (_rewardType == RewardType.TOKEN) {
            require(_tokenAddress != address(0), "Enter valid token Address");
        }
        if (_rewardType == RewardType.NFT) {
            require(_tokenAddress != address(0), "Enter valid token Address");
            require(_nftTokenIds.length > 0, "Enter NFTs for reward");
        }

        // Create the event
        events.push(
            Event({
                id: nextEventId,
                creator: msg.sender,
                name: name,
                description: description,
                timestamp: timestamp,
                endAt: _endAt,
                rewardType: _rewardType,
                totalParticipant: 0,
                tokenAddress: _tokenAddress,
                amountReward: _amountReward,
                firstregistrantBonus: _firstregistrantBonus,
                nftTokenIds: _nftTokenIds,
                nftBonusId: bonusNft
            })
        );

        // Increment the event ID
        nextEventId++;
    }

    //fetch event by ID
    function getEvent(uint256 id) public view returns (Event memory) {
        if (id >= events.length) revert("Event does not exist");
        return events[id];
    }

    // Fetch all events
    function getAllEvents() public view returns (Event[] memory) {
        return events;
    }

    // Function to add events for testing purposes
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
        uint256 _endAt,
        uint256[] memory _nftTokenIds,
        uint256 bonusNft
    ) public {
        events.push(
            Event({
                id: id,
                description: description,
                creator: creator,
                name: name,
                timestamp: timestamp,
                endAt: _endAt,
                rewardType: rewardType,
                totalParticipant: 0,
                tokenAddress: _tokenAddress,
                amountReward: _amountReward,
                firstregistrantBonus: _firstregistrantBonus,
                nftTokenIds: _nftTokenIds,
                nftBonusId: bonusNft
            })
        );
    }

    function getWorldId() public view returns (IWorldID) {
        return worldId;
    }

    //Register For Event
    function registerParticipant(
        uint256 eventId,
        uint256 root,
        uint256 nullifierHash,
        uint256[8] memory proof
    ) public {
        Event storage eventData = events[eventId];
        require(
            eventData.timestamp > block.timestamp,
            "Event has already started"
        );
        require(!isParticipant[eventId][msg.sender], "Already Registered");

        // Verify the participant using World ID
        worldId.verifyProof(
            root,
            nullifierHash,
            msg.sender,
            appId,
            actionId,
            proof
        );

        ++eventData.totalParticipant;
        isParticipant[eventId][msg.sender] = true;
        eventParticipant[eventId].push(msg.sender);

        emit RegisteredSuccessful(eventId, msg.sender);
    }

    //Set event merkle root
    function setEventMerkleRoot(uint256 eventId, bytes32 _merkleRoot) external {
        Event storage eventData = events[eventId];
        require(
            msg.sender == eventData.creator,
            "Only event creator can set root"
        );
        EventNFT nftContract = EventNFT(eventData.tokenAddress);
        nftContract.setMerkleRoot(_merkleRoot);
    }

    function claimReward(
        uint256 eventId,
        uint256 nullifierHash,
        bytes32[] calldata proof
    ) external {
        require(!nullifierHashes[eventId][nullifierHash], "Hash already used");
        require(isParticipant[eventId][msg.sender], "Not a participant");
        require(
            !hasClaimedReward[eventId][msg.sender],
            "Reward already claimed"
        );
        Event storage eventData = events[eventId];
        if (eventData.rewardType == RewardType.TOKEN) {
            address tokenAddress = eventData.tokenAddress;

            uint256 totalReward = eventData.amountReward;
            if (msg.sender == eventParticipant[eventData.id][0]) {
                totalReward += eventData.firstregistrantBonus;
            }

            require(
                IERC20(tokenAddress).balanceOf(address(this)) >= totalReward,
                "Insufficient reward balance"
            );

            IERC20(eventData.tokenAddress).transfer(msg.sender, totalReward);
        }

        if (eventData.rewardType == RewardType.NFT) {
            EventNFT nftContract = EventNFT(eventData.tokenAddress);
            nftContract.claimNFT(msg.sender, proof);

            // Handle bonus NFT for the first registrant
            if (msg.sender == eventParticipant[eventData.id][0]) {
                require(
                    IERC721(tokenAddress).balanceOf(address(this)),
                    "Insuffucient NFT Reward"
                );
                require(
                    IERC721(eventData.tokenAddress).ownerOf(
                        eventData.nftBonusId
                    ) == address(this),
                    "Contract does not own the bonus NFT"
                );
                IERC721(tokenAddress).safeTransferFrom(
                    address(this),
                    msg.sender,
                    eventData.nftBonusId
                );
            }
        }

        hasClaimedReward[eventData.id][msg.sender] = true;
        nullifierHashes[eventId][nullifierHash] = true;
    }
}
