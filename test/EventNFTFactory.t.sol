// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/EventNFTFactory.sol";
import "../src/EventNFT.sol";

contract EventNFTFactoryTest is Test {
    EventNFTFactory public factory;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        factory = new EventNFTFactory();
    }

    function testCreateEventNFT() public {
        string memory name = "Test Event";
        string memory symbol = "TEST";
        uint256 maxSupply = 100;
        string memory baseURI = "https://example.com/metadata/";
        address eventContract = address(0x2);

        (EventNFT newEventNFT, uint256 length) = factory.createEventNFT(
            name,
            symbol,
            maxSupply,
            baseURI,
            eventContract
        );

        assertEq(length, 1, "EventNFTs array length should be 1");
        assertEq(address(newEventNFT).code.length > 0, true, "EventNFT should be deployed");

        // Verify EventNFT properties
        assertEq(newEventNFT.name(), name, "EventNFT name should match");
        assertEq(newEventNFT.symbol(), symbol, "EventNFT symbol should match");
        assertEq(newEventNFT.maxSupply(), maxSupply, "EventNFT maxSupply should match");
        assertEq(newEventNFT.eventContract(), eventContract, "EventNFT eventContract should match");
        assertEq(newEventNFT.owner(), owner, "EventNFT owner should match");
    }

    function testGetEventNFTClones() public {
        // Create multiple EventNFTs
        factory.createEventNFT("Event 1", "EV1", 100, "uri1", address(0x3));
        factory.createEventNFT("Event 2", "EV2", 200, "uri2", address(0x4));

        EventNFT[] memory eventNFTs = factory.getEventNFTClones();

        assertEq(eventNFTs.length, 2, "Should have created 2 EventNFTs");
        assertEq(eventNFTs[0].name(), "Event 1", "First EventNFT name should match");
        assertEq(eventNFTs[1].name(), "Event 2", "Second EventNFT name should match");
    }

    function testCreateMultipleEventNFTs() public {
        uint256 numNFTs = 5;

        for (uint256 i = 0; i < numNFTs; i++) {
            string memory name = string(abi.encodePacked("Event ", vm.toString(i + 1)));
            string memory symbol = string(abi.encodePacked("EV", vm.toString(i + 1)));
            factory.createEventNFT(name, symbol, 100 * (i + 1), "uri", address(uint160(i + 1)));
        }

        EventNFT[] memory eventNFTs = factory.getEventNFTClones();
        assertEq(eventNFTs.length, numNFTs, "Should have created 5 EventNFTs");

        for (uint256 i = 0; i < numNFTs; i++) {
            assertEq(eventNFTs[i].name(), string(abi.encodePacked("Event ", vm.toString(i + 1))), "EventNFT name should match");
            assertEq(eventNFTs[i].maxSupply(), 100 * (i + 1), "EventNFT maxSupply should match");
        }
    }

    function testEventEmission() public {
        vm.recordLogs();
        
        (EventNFT newEventNFT,) = factory.createEventNFT("Test Event", "TEST", 100, "uri", address(0x5));
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 2, "Should have 2 events emitted");
        
        assertEq(entries[1].topics[0], keccak256("EventNFTCreated(address,address)"), "Event signature should match");
        assertEq(address(uint160(uint256(entries[1].topics[1]))), address(newEventNFT), "EventNFT address should match");
        assertEq(address(uint160(uint256(entries[1].topics[2]))), owner, "Owner address should match");
    }
}