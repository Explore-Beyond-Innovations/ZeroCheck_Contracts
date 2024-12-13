// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract EventManager {
    struct Event {
        uint256 id;
        address creator;
        string description;
    }

   
    Event[] public events;


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
    function addEventForTesting(uint256 id, string memory description, address creator) public {
        events.push(Event({
            id: id,
            description: description,
            creator: creator
        }));
    }
}
