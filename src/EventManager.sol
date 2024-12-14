// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Merkle} from "murky/src/Merkle.sol";

contract EventManager is Merkle {
    struct Event {
        uint256 id;
        string description;
        address creator;
        address[] participants;
        bytes32 merkleRoot;
    }

    event ParticipantRegistered(uint256 eventId, address indexed participant);
    event MerkleRootGenerated(uint256 eventId, bytes32 merkleRoot);

    mapping(uint256 => Event) private events;
    uint256[] private eventIds;
    uint256 private nextEventId;

    mapping(uint256 => mapping(address => bool)) private registeredParticipants;

    /// @dev Register a participant for an existing event.
    /// @param eventId The ID of the event to register for.
    function registerParticipant(uint256 eventId) public {
        require(eventId < nextEventId, "Event does not exist");
        require(!registeredParticipants[eventId][msg.sender], "Already registered as participant");

        events[eventId].participants.push(msg.sender);
        registeredParticipants[eventId][msg.sender] = true;

        emit ParticipantRegistered(eventId, msg.sender);
    }

    /// @dev Generate a Merkle root for the registered participants of an event.
    /// @param eventId The ID of the event.
    function generateMerkleRoot(uint256 eventId) public {
        require(eventId < nextEventId, "Event does not exist");
        require(msg.sender == events[eventId].creator, "Only the event creator can generate the Merkle root");

        address[] memory participants = events[eventId].participants;
        bytes32[] memory leafs = new bytes32[](participants.length);

        for (uint256 i = 0; i < participants.length; i++) {
            leafs[i] = keccak256(abi.encodePacked(participants[i]));
        }

        bytes32 merkleRoot = getRoot(leafs);
        events[eventId].merkleRoot = merkleRoot;

        emit MerkleRootGenerated(eventId, merkleRoot);
    }

    /// @dev Retrieve the Merkle root for an event.
    /// @param eventId The ID of the event.
    function getMerkleRoot(uint256 eventId) public view returns (bytes32) {
        require(eventId < nextEventId, "Event does not exist");
        return events[eventId].merkleRoot;
    }

    /// @dev Get all participants of an event.
    /// @param eventId The ID of the event.
    function getParticipants(uint256 eventId) public view returns (address[] memory) {
        require(eventId < nextEventId, "Event does not exist");
        return events[eventId].participants;
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

    // Test helper: Add event for testing only
    function addEventForTesting(uint256 id, string memory description, address creator) public {
        require(events[id].id == 0, "Event already exists");

        events[id] = Event({
            id: id,
            description: description,
            creator: creator,
            participants: new address[](0),
            merkleRoot: bytes32(0)
        });

        eventIds.push(id);
    }
}
