// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";

contract EventManagerTest is Test {
    EventManager private eventManager;
    address private creator = address(1);
    address private participant1 = address(2);
    address private participant2 = address(3);

    event EventRegistered(uint256 id, string description, address indexed creator);

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

    function testGetAllEvents() public {
        // Use the test function to add events
        eventManager.addEventForTesting(0, "First Event", address(this));
        eventManager.addEventForTesting(1, "Second Event", address(this));

        EventManager.Event[] memory events = eventManager.getAllEvents();
        assertEq(events.length, 2);
        assertEq(events[0].description, "First Event");
        assertEq(events[1].description, "Second Event");
    }

    function testRegisterParticipant() public {
        // Register participant 1
        vm.prank(participant1);
        eventManager.registerParticipant(0);

        address[] memory participants = eventManager.getParticipants(0);
        assertEq(participants.length, 1);
        assertEq(participants[0], participant1);

        // Register participant 2
        vm.prank(participant2);
        eventManager.registerParticipant(0);

        participants = eventManager.getParticipants(0);
        assertEq(participants.length, 2);
        assertEq(participants[1], participant2);

        vm.expectRevert("Already registered as participant");
        vm.prank(participant1);
        eventManager.registerParticipant(0);
    }

    function testGenerateMerkleRoot() public {
        vm.prank(participant1);
        eventManager.registerParticipant(0);

        vm.prank(participant2);
        eventManager.registerParticipant(0);

        vm.prank(creator);
        eventManager.generateMerkleRoot(0);

        bytes32 merkleRoot = eventManager.getMerkleRoot(0);
        assertTrue(merkleRoot != bytes32(0), "Merkle root should not be empty");
    }

    function testOnlyCreatorCanGenerateMerkleRoot() public {
        vm.prank(participant1);
        eventManager.registerParticipant(0);

        vm.prank(participant2);
        eventManager.registerParticipant(0);

        vm.expectRevert("Only the event creator can generate the Merkle root");
        vm.prank(participant1);
        eventManager.generateMerkleRoot(0);
    }
}
