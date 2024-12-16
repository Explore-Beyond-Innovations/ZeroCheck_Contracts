// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";
import "../src/interfaces/IWorldID.sol";

contract MockWorldID is IWorldID {
  function verifyProof(uint256, address, bytes calldata) external pure returns (bool) {
    return true; // Mock implementation
  }
}

contract EventManagerTest is Test {
  EventManager private eventManager;

  MockWorldID private mockWorldID;
  address constant REWARD_CONTRACT = address(0x5678);

  function setUp() public {
    mockWorldID = new MockWorldID();
    eventManager = new EventManager(mockWorldID, REWARD_CONTRACT, "appId", "actionId");
  }

  function testEventManagerConstruction() public view {
    assertEq(address(eventManager.getWorldId()), address(mockWorldID));
    assertEq(eventManager.rewardContract(), REWARD_CONTRACT);
    assertEq(eventManager.appId(), "appId");
    assertEq(eventManager.actionId(), "actionId");
  }

  function testGetEvent() public {
    // Use the test function to add an event
    eventManager.addEventForTesting(
      0, "Test Event", address(this), "Event Name", block.timestamp + 1 days, "Gold"
    );

    EventManager.Event memory evt = eventManager.getEvent(0);
    assertEq(evt.description, "Test Event");
    assertEq(evt.creator, address(this));
    assertEq(evt.id, 0);
    assertEq(evt.name, "Event Name");
    assertEq(evt.timestamp, block.timestamp + 1 days);
    assertEq(evt.rewardType, "Gold");
  }

  function testGetNonExistentEvent() public {
    vm.expectRevert("Event does not exist");
    eventManager.getEvent(0);
  }

  function testGetAllEvents() public {
    // Use the test function to add events
    eventManager.addEventForTesting(
      0, "First Event", address(this), "Event One", block.timestamp + 1 days, "Gold"
    );
    eventManager.addEventForTesting(
      1, "Second Event", address(this), "Event Two", block.timestamp + 2 days, "Silver"
    );

    EventManager.Event[] memory events = eventManager.getAllEvents();
    assertEq(events.length, 2);
    assertEq(events[0].description, "First Event");
    assertEq(events[1].description, "Second Event");
    assertEq(events[0].name, "Event One");
    assertEq(events[1].rewardType, "Silver");
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
