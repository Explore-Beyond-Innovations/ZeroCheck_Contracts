// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";

contract EventManagerTest is Test {
    EventManager private eventManager;

    function setUp() public {
        eventManager = new EventManager();
    }

    function testEventManagerConstruction() public {
        assertEq(eventManager.worldID(), address(1));
        assertEq(eventManager.rewardContract(), address(2));
        assertEq(eventManager.appId(), "appId");
        assertEq(eventManager.actionId(), "actionId");
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
}
