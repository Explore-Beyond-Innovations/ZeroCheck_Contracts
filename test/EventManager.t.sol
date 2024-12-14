// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";

contract EventManagerTest is Test {
    EventManager private eventManager;
    address constant WORLD_ID_CONTRACT = address(0x1234);
    uint256 constant WORLD_ID_ROOT = 123456789;
    
    event EventRegistered(uint256 id, string description, address indexed creator);

    function setUp() public {
        eventManager = new EventManager(WORLD_ID_CONTRACT, WORLD_ID_ROOT);
    }

    function testGetEvent() public {
        // Use the test function to add an event
        eventManager.addEventForTesting(0, "Test Event", address(this));

        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.description, "Test Event");
        assertEq(evt.creator, address(this));
        assertEq(evt.id, 0);
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

    function testRegisterEvent() public {
        string memory description = "World ID Event";
        uint256 nullifierHash = 12345;
        uint256[8] memory proof =
            [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7), uint256(8)];

        vm.mockCall(
            WORLD_ID_CONTRACT,
            abi.encodeWithSignature("verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof),
            abi.encode(true)
        );

        vm.expectEmit(true, true, false, true);
        emit EventRegistered(0, description, address(this));

        eventManager.registerEvent(description, nullifierHash, proof);

        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.description, "World ID Event");
        assertEq(evt.creator, address(this));
    }

    function testDoubleRegistrationFails() public {
        uint256 nullifierHash = 12345;
        uint256[8] memory proof =
            [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7), uint256(8)];

        vm.mockCall(
            WORLD_ID_CONTRACT,
            abi.encodeWithSignature("verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof),
            abi.encode(true)
        );

        eventManager.registerEvent("First Event", nullifierHash, proof);

        vm.expectRevert("Already registered");
        eventManager.registerEvent("Second Event", nullifierHash, proof);
    }
}
