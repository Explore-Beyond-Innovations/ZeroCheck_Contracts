// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IWorldID} from "./interfaces/IWorldID.sol";

contract EventManager {
    struct Event {
        uint256 id;
        string description;
        address creator;
    }

    event EventRegistered(uint256 id, string description, address indexed creator);

    mapping(uint256 => Event) private events;
    uint256[] private eventIds;
    uint256 private nextEventId;

    mapping(uint256 => bool) private nullifierHashes;

    IWorldID public worldId;
    uint256 public worldIdRoot;

    constructor(address _worldId, uint256 _root) {
        worldId = IWorldID(_worldId);
        worldIdRoot = _root;
    }

    // Register an event using World ID verification
    function registerEvent(string memory description, uint256 nullifierHash, uint256[8] calldata proof) public {
        require(bytes(description).length > 0, "Description cannot be empty");
        require(!nullifierHashes[nullifierHash], "Already registered");

        // Verify World ID proof
        worldId.verifyProof(worldIdRoot, nullifierHash, proof);

        // Register the event
        uint256 id = nextEventId++;
        events[id] = Event(id, description, msg.sender);
        eventIds.push(id);

        // Mark nullifierHash as used
        nullifierHashes[nullifierHash] = true;

        emit EventRegistered(id, description, msg.sender);
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
        events[id] = Event(id, description, creator);
        eventIds.push(id);
    }
}
