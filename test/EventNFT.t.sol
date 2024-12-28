// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {EventNFT} from "../src/EventNFT.sol";
import {Merkle} from "murky/src/Merkle.sol";
import "../src/interfaces/IWorldID.sol";

contract MockWorldID is IWorldID {
    bool private isValid;
    mapping(uint256 => bool) public nullifierHashes;

    error InvalidNullifier();

    constructor() {
        isValid = true;
    }

    function setValid(bool _isValid) external {
        isValid = _isValid;
    }

    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof
    ) external view override {
        require(isValid, "Mock WorldID: Invalid proof");
        if (nullifierHashes[nullifierHash]) {
            revert InvalidNullifier();
        }
        require(root != 0, "Mock WorldID: Invalid root");
        require(groupId != 0, "Mock WorldID: Invalid group ID");
        require(signal != 0, "Mock WorldID: Invalid signal");
        require(nullifierHash != 0, "Mock WorldID: Invalid nullifier hash");
        require(externalNullifier != 0, "Mock WorldID: Invalid external nullifier");
        require(proof.length == 8, "Mock WorldID: Invalid proof length");
    }

    function registerNullifier(uint256 nullifierHash) external {
        nullifierHashes[nullifierHash] = true;
    }

    function isNullifierUsed(uint256 nullifierHash) external view returns (bool) {
        return nullifierHashes[nullifierHash];
    }
}

contract EventNFTTest is Test, Merkle {
    EventNFT private eventNFT;
    MockWorldID private worldId;
    
    address private owner;
    address private eventContract;
    address private participant1;
    address private participant2;
    address private nonParticipant;

    uint256 private constant WORLD_ID_ROOT = 1;
    uint256 private constant GROUP_ID = 1;
    uint256 private constant EXTERNAL_NULLIFIER = 1;
    uint256[8] private proof;

    event AttemptingClaim(address participant, uint256 nextTokenId);
    event ClaimSuccessful(address participant, uint256 tokenId);

    function setUp() public {
        owner = address(1);
        eventContract = address(2);
        participant1 = address(3);
        participant2 = address(4);
        nonParticipant = address(5);
        
        worldId = new MockWorldID();
        
        // Initialize proof array
        for(uint i = 0; i < 8; i++) {
            proof[i] = i + 1; // Simple non-zero values
        }

        eventNFT = new EventNFT(
            "EventNFT",
            "ENFT",
            100,
            "https://base.uri/",
            "https://bonusbase.uri/",
            eventContract,
            owner,
            address(worldId)
        );
        
        vm.label(owner, "Owner");
        vm.label(eventContract, "Event Contract");
        vm.label(participant1, "Participant 1");
        vm.label(participant2, "Participant 2");
    }

    function testInitialState() public {
        assertEq(eventNFT.owner(), owner);
        assertEq(eventNFT.eventContract(), eventContract);
        assertEq(eventNFT.maxSupply(), 100);
        assertEq(eventNFT.worldIDAddr(), address(worldId));
    }

    function testSetEventContract() public {
        address newEventContract = address(10);
        
        vm.prank(owner);
        eventNFT.setEventContract(newEventContract);
        
        assertEq(eventNFT.eventContract(), newEventContract);
    }

    function testFailSetEventContractNonOwner() public {
        address newEventContract = address(10);
        
        vm.prank(participant1);
        eventNFT.setEventContract(newEventContract);
    }

    function testFailSetEventContractZeroAddress() public {
        vm.prank(owner);
        eventNFT.setEventContract(address(0));
    }

    function testSuccessfulClaim() public {
        uint256 nullifierHash = 123;
        
        vm.prank(eventContract);
        vm.expectEmit(true, true, true, true);
        emit AttemptingClaim(participant1, 0);
        
        vm.expectEmit(true, true, true, true);
        emit ClaimSuccessful(participant1, 0);
        
        (bool success, address claimant, uint256 tokenId) = eventNFT.claimNFTWithZk(
            WORLD_ID_ROOT,
            GROUP_ID,
            nullifierHash,
            EXTERNAL_NULLIFIER,
            proof,
            participant1
        );
        
        assertTrue(success);
        assertEq(claimant, participant1);
        assertEq(tokenId, 0);
        assertTrue(eventNFT.hasClaimedNFT(participant1));
        assertEq(eventNFT.ownerOf(0), participant1);
    }

    function testFailClaimNonEventContract() public {
        uint256 nullifierHash = 123;
        
        vm.prank(participant1);
        eventNFT.claimNFTWithZk(
            WORLD_ID_ROOT,
            GROUP_ID,
            nullifierHash,
            EXTERNAL_NULLIFIER,
            proof,
            participant1
        );
    }

    function testFailClaimWithInvalidWorldIDProof() public {
        uint256 nullifierHash = 123;
        worldId.setValid(false);
        
        vm.prank(eventContract);
        eventNFT.claimNFTWithZk(
            WORLD_ID_ROOT,
            GROUP_ID,
            nullifierHash,
            EXTERNAL_NULLIFIER,
            proof,
            participant1
        );
    }

    function testFailClaimWithUsedNullifier() public {
        uint256 nullifierHash = 123;
        worldId.registerNullifier(nullifierHash);
        
        vm.prank(eventContract);
        eventNFT.claimNFTWithZk(
            WORLD_ID_ROOT,
            GROUP_ID,
            nullifierHash,
            EXTERNAL_NULLIFIER,
            proof,
            participant1
        );
    }

    function testFailClaimBeyondMaxSupply() public {
        // Create NFT with max supply of 1
        EventNFT limitedNFT = new EventNFT(
            "LimitedNFT",
            "LNFT",
            1,
            "https://base.uri/",
            "https://bonusbase.uri/",
            eventContract,
            owner,
            address(worldId)
        );
        
        uint256 nullifierHash1 = 123;
        uint256 nullifierHash2 = 456;
        
        // First claim should succeed
        vm.prank(eventContract);
        limitedNFT.claimNFTWithZk(
            WORLD_ID_ROOT,
            GROUP_ID,
            nullifierHash1,
            EXTERNAL_NULLIFIER,
            proof,
            participant1
        );
        
        // Second claim should fail
        vm.prank(eventContract);
        limitedNFT.claimNFTWithZk(
            WORLD_ID_ROOT,
            GROUP_ID,
            nullifierHash2,
            EXTERNAL_NULLIFIER,
            proof,
            participant2
        );
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