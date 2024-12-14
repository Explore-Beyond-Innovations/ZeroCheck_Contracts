// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract EventManager {
    struct Event {
        uint256 id;
        address creator;
        string description;
        string name;
        uint256 timestamp;
        string rewardType;
    }

    Event[] public events;

    //  State Variable for Create Events
    uint256 public nextEventId;

    // Create Events Function
    function createEvent(string memory name, string memory description, uint256 timestamp, string memory rewardType)
        public
    {
        // Validation checks
        require(bytes(name).length > 0, "Event name is required");
        require(bytes(description).length > 0, "Description is required");
        require(timestamp > block.timestamp, "Timestamp must be in the future");
        require(bytes(rewardType).length > 0, "Reward type is required");

        // Create the event
        events.push(
            Event({
                id: nextEventId,
                creator: msg.sender,
                name: name,
                description: description,
                timestamp: timestamp,
                rewardType: rewardType
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
        string memory rewardType
    ) public {
        events.push(
            Event({
                id: id,
                description: description,
                creator: creator,
                name: name,
                timestamp: timestamp,
                rewardType: rewardType
            })
        );
    }
}
