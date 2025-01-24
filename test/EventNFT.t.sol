// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {EventNFT} from "../src/EventNFT.sol";

contract EventNFTTest is Test {
    EventNFT private eventNFT;

    address private owner;
    address private eventManager;
    address private participant1;
    address private participant2;
    address private nonParticipant;

    event AttemptingClaim(address participant, uint256 nextTokenId);
    event ClaimSuccessful(address participant, uint256 tokenId);

    function setUp() public {
        owner = address(1);
        eventManager = address(2);
        participant1 = address(3);
        participant2 = address(4);
        nonParticipant = address(5);

        vm.prank(owner);

        eventNFT = new EventNFT("EventNFT", "ENFT", 100, "https://base.uri/", "https://bonusbase.uri/", eventManager);

        vm.label(owner, "Owner");
        vm.label(eventManager, "Event Contract");
        vm.label(participant1, "Participant 1");
        vm.label(participant2, "Participant 2");
    }

    function testInitialState() public view {
        assertEq(eventNFT.owner(), owner, "Owner address mismatch");
        assertEq(eventNFT.eventManager(), eventManager, "Event contract address mismatch");
        assertEq(eventNFT.maxSupply(), 100, "Max supply mismatch");
    }

    function testFailSetEventContractNonOwner() public {
        address newEventContract = address(10);

        vm.prank(participant1);
        eventNFT.setEventManager(newEventContract);
    }

    function testFailSetEventContractZeroAddress() public {
        vm.prank(owner);
        eventNFT.setEventManager(address(0));
    }

    function testSuccessfulClaim() public {
        vm.prank(eventManager);
        vm.expectEmit(true, true, true, true);
        emit AttemptingClaim(participant1, 0);

        vm.expectEmit(true, true, true, true);
        emit ClaimSuccessful(participant1, 0);

        uint256 tokenId = eventNFT.claimNFT(participant1);
        assertEq(tokenId, 0);
        assertTrue(eventNFT.hasClaimedNFT(participant1));
        assertEq(eventNFT.ownerOf(0), participant1);
    }

    function testFailClaimNonEventContract() public {
        vm.prank(participant1);
        eventNFT.claimNFT(participant1);
    }

    function testFailClaimBeyondMaxSupply() public {
        // Create NFT with max supply of 1
        EventNFT limitedNFT =
            new EventNFT("LimitedNFT", "LNFT", 1, "https://base.uri/", "https://bonusbase.uri/", eventManager);

        // First claim should succeed
        vm.prank(eventManager);
        limitedNFT.claimNFT(participant1);

        // Second claim should fail
        vm.prank(eventManager);
        limitedNFT.claimNFT(participant2);
    }

    function testSetBaseURI() public {
        string memory newBaseURI = "https://new.base.uri/";

        vm.prank(owner);
        eventNFT.setBaseURI(newBaseURI);
    }

    function testFailSetBaseURINonOwner() public {
        string memory newBaseURI = "https://new.base.uri/";

        vm.prank(participant1);
        eventNFT.setBaseURI(newBaseURI);
    }
}
