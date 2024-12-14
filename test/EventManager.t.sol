// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";

contract EventManagerTest is Test {
    EventManager private eventManager;
    address constant WORLD_ID_CONTRACT = address(0x1234);
    uint256 constant WORLD_ID_ROOT = 123456789;

<<<<<<< HEAD
    event ParticipantRegistered(uint256 eventId, address indexed participant);
=======
    event EventRegistered(uint256 id, string description, address indexed creator);
>>>>>>> 17c7e11 (forge fmt)

    function setUp() public {
        eventManager = new EventManager(WORLD_ID_CONTRACT, WORLD_ID_ROOT);
    }

    function testGetEvent() public {
<<<<<<< HEAD
        // Use the createEvent function to add an event
        eventManager.createEvent(
            "Test Event",
            "Event Name",
            block.timestamp + 1 days,
            "Gold"
        );
=======
        eventManager.createEvent("Event Name", "Test Event", block.timestamp + 1 days, "Gold");
>>>>>>> c5efe6b (Resolve conflicts)

        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.description, "Test Event");
        assertEq(evt.creator, address(this));
        assertEq(evt.id, 0);
        assertEq(evt.name, "Event Name");
        assertEq(evt.timestamp, block.timestamp + 1 days);
        assertEq(evt.rewardType, "Gold");
    }

    function testGetAllEvents() public {
<<<<<<< HEAD
        // Use the createEvent function to add events
        eventManager.createEvent(
            "First Event",
            "Event One",
            block.timestamp + 1 days,
            "Gold"
        );
        eventManager.createEvent(
            "Second Event",
            "Event Two",
            block.timestamp + 2 days,
            "Silver"
        );
=======
        eventManager.createEvent("Event One", "First Event", block.timestamp + 1 days, "Gold");
        eventManager.createEvent("Event Two", "Second Event", block.timestamp + 2 days, "Silver");
>>>>>>> c5efe6b (Resolve conflicts)

        EventManager.Event[] memory events = eventManager.getAllEvents();
        assertEq(events.length, 2);
        assertEq(events[0].description, "First Event");
        assertEq(events[1].description, "Second Event");
        assertEq(events[0].name, "Event One");
        assertEq(events[1].rewardType, "Silver");
    }

    function testCreateEventSuccess() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory eventDescription = "This is a test event";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory eventRewardType = "Token";

        // Act
        eventManager.createEvent(
            eventName,
            eventDescription,
            eventTimestamp,
            eventRewardType
        );

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
        eventManager.createEvent(
            emptyName,
            eventDescription,
            eventTimestamp,
            eventRewardType
        );
    }

    function testCreateEventFailsWhenDescriptionIsEmpty() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory emptyDescription = "";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory eventRewardType = "Token";

        // Act & Assert
        vm.expectRevert(bytes("Description is required"));
        eventManager.createEvent(
            eventName,
            emptyDescription,
            eventTimestamp,
            eventRewardType
        );
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
        eventManager.createEvent(
            eventName,
            eventDescription,
            pastTimestamp,
            eventRewardType
        );
    }

    function testCreateEventFailsWhenRewardTypeIsEmpty() public {
        // Arrange
        string memory eventName = "Test Event";
        string memory eventDescription = "This is a test event";
        uint256 eventTimestamp = block.timestamp + 1 days;
        string memory emptyRewardType = "";

        // Act & Assert
        vm.expectRevert(bytes("Reward type is required"));
        eventManager.createEvent(
            eventName,
            eventDescription,
            eventTimestamp,
            emptyRewardType
        );
    }

    function testRegisterParticipantSuccess() public {
        // Arrange
        uint256 nullifierHash = 12345;
        uint256[8] memory proof = [
            uint256(1),
            uint256(2),
            uint256(3),
            uint256(4),
            uint256(5),
            uint256(6),
            uint256(7),
            uint256(8)
        ];

        // Mock call for World ID proof verification
        vm.mockCall(
            WORLD_ID_CONTRACT,
            abi.encodeWithSignature(
                "verifyProof(uint256,uint256,uint256[8])",
                WORLD_ID_ROOT,
                nullifierHash,
                proof
            ),
            abi.encode(true)
        );

        // Create a test event
        eventManager.createEvent(
            "World ID Event",
            "Event Name",
            block.timestamp + 1 days,
            "Token"
        );

        // Act
        vm.expectEmit(true, true, false, true);
        emit ParticipantRegistered(0, address(this));

        eventManager.registerParticipant(0, nullifierHash, proof);

        // Assert
        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.participants.length, 1);
        assertEq(evt.participants[0], address(this));
    }

    function testDoubleRegistrationFails() public {
        // Arrange
        uint256 nullifierHash = 12345;
        uint256[8] memory proof = [
            uint256(1),
            uint256(2),
            uint256(3),
            uint256(4),
            uint256(5),
            uint256(6),
            uint256(7),
            uint256(8)
        ];

        vm.mockCall(
            WORLD_ID_CONTRACT,
            abi.encodeWithSignature(
                "verifyProof(uint256,uint256,uint256[8])",
                WORLD_ID_ROOT,
                nullifierHash,
                proof
            ),
            abi.encode(true)
        );

        eventManager.createEvent(
            "World ID Event",
            "Event Name",
            block.timestamp + 1 days,
            "Token"
        );

        // Act
        eventManager.registerParticipant(0, nullifierHash, proof);

        // Assert
        vm.expectRevert("Already registered as participant");
        eventManager.registerParticipant(0, nullifierHash, proof);
    }

    function testRegisterParticipantSuccess() public {
        // Arrange
        uint256 nullifierHash = 12345;
        uint256[8] memory proof =
            [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7), uint256(8)];

        // Mock call for World ID proof verification
        vm.mockCall(
            WORLD_ID_CONTRACT,
            abi.encodeWithSignature("verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof),
            abi.encode(true)
        );

        eventManager.createEvent("World ID Event", "Event Name", block.timestamp + 1 days, "Token");

        // Act
        vm.expectEmit(true, true, false, true);
        emit ParticipantRegistered(0, address(this));

        eventManager.registerParticipant(0, nullifierHash, proof);

        // Assert
        EventManager.Event memory evt = eventManager.getEvent(0);
        assertEq(evt.participants.length, 1);
        assertEq(evt.participants[0], address(this));
    }

    function testDoubleRegistrationFails() public {
        // Arrange
        uint256 nullifierHash = 12345;
        uint256[8] memory proof =
            [uint256(1), uint256(2), uint256(3), uint256(4), uint256(5), uint256(6), uint256(7), uint256(8)];

        vm.mockCall(
            WORLD_ID_CONTRACT,
            abi.encodeWithSignature("verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof),
            abi.encode(true)
        );

        eventManager.createEvent("World ID Event", "Event Name", block.timestamp + 1 days, "Token");

        // Act
        eventManager.registerParticipant(0, nullifierHash, proof);

        // Assert
        vm.expectRevert("Already registered as participant");
        eventManager.registerParticipant(0, nullifierHash, proof);
    }
}
