// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";

contract EventManagerTest is Test {
    EventManager private eventManager;

    function setUp() public {
        eventManager = new EventManager();
    }

    function testGetEvent() public {
        // Use the test function to add an event
        eventManager.addEventForTesting(0, "Test Event", address(this));

        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.description, "Test Event");
        assertEq(evt.creator, address(this));
        assertEq(evt.id, 0);
    }

    function testGetNonExistentEvent() public {
        vm.expectRevert("Event does not exist");
        eventManager.getEvent(0);
    }

    function testGetAllEvents() public {
        // Use the test function to add events
        eventManager.addEventForTesting(0, "First Event", address(this));
        eventManager.addEventForTesting(1, "Second Event", address(this));

        EventManager.Event[] memory events = eventManager.getAllEvents();
        assertEq(events.length, 2);
        assertEq(events[0].description, "First Event");
        assertEq(events[1].description, "Second Event");
    }

    // Unit Test for Create Events
    function testCreateEventSuccess() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory eventDescription = "This is a test event";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory eventRewardType = "Token";

        // Act
        eventManager.createEvent(eventName, eventDescription, eventTimestamp, eventRewardType);

        // Assert
        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.id, 0);
        assertEq(evt.creator, address(this));
        assertEq(evt.description, eventDescription);
        assertEq(evt.name, eventName);
        assertEq(evt.timestamp, eventTimestamp);
        assertEq(evt.rewardType, eventRewardType);
    }

    function testCreateEventFailsWhenNameIsEmpty() public {
        // Arrange
        string memory emptyName = "";
        string memory eventDescription = "This is a test event";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory eventRewardType = "Token";

        // Act & Assert
        vm.expectRevert(bytes("Event name is required"));
        eventManager.createEvent(emptyName, eventDescription, eventTimestamp, eventRewardType);
    }

    function testCreateEventFailsWhenDescriptionIsEmpty() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory emptyDescription = "";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory eventRewardType = "Token";

        // Act & Assert
        vm.expectRevert(bytes("Description is required"));
        eventManager.createEvent(eventName, emptyDescription, eventTimestamp, eventRewardType);
    }

    function testCreateEventFailsWhenTimestampIsNotFuture() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory eventDescription = "This is a test event";
        uint256 currentTime = block.timestamp;
        uint256 pastTimestamp = currentTime - 1;
        string memory eventRewardType = "Token";

        // Act
        vm.expectRevert(bytes("Timestamp must be in the future"));

        // Assert
        eventManager.createEvent(eventName, eventDescription, pastTimestamp, eventRewardType);
    }

    function testCreateEventFailsWhenRewardTypeIsEmpty() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory eventDescription = "This is a test event";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory emptyRewardType = "";

        // Act & Assert
        vm.expectRevert(bytes("Reward type is required"));
        eventManager.createEvent(eventName, eventDescription, eventTimestamp, emptyRewardType);
    }
}
