// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import {EventNFT} from "../src/EventNFT.sol";
import {Merkle} from "murky/src/Merkle.sol";

contract EventNFTTest is Test, Merkle {
    EventNFT private eventNFT;
    address private owner;
    address private eventContract;
    address private participant1;
    address private participant2;
    bytes32 private merkleRoot;

    // Sample Merkle Tree for testing
    bytes32[] private proof1;
    bytes32[] private proof2;
    bytes32[] private leafs;

    function setUp() public {
        owner = address(1);
        eventContract = address(2);
        participant1 = address(3);
        participant2 = address(4);

        eventNFT = new EventNFT("EventNFT", "ENFT", 100, "https://base.uri/", eventContract, owner);

        leafs.push(keccak256(abi.encodePacked(participant1)));
        leafs.push(keccak256(abi.encodePacked(participant2)));

        merkleRoot = getRoot(leafs);
        proof1 = getProof(leafs, 0);
        proof2 = getProof(leafs, 1);

        vm.prank(owner);
        eventNFT.setMerkleRoot(merkleRoot);
    }

    function testDeploy() public view {
        assertEq(eventNFT.owner(), owner, "Owner address mismatch");
        assertEq(eventNFT.eventContract(), eventContract, "Event contract address mismatch");
        assertEq(eventNFT.maxSupply(), 100, "Max supply mismatch");
    }

    function testClaimNFT() public {
        vm.prank(eventContract);
        eventNFT.claimNFT(participant1, proof1);

        assertTrue(eventNFT.claimed(participant1), "Participant1 should have claimed their NFT");

        assertEq(eventNFT.balanceOf(participant1), 1, "Participant1 should have 1 token");

        // Participant2 claims their NFT
        vm.prank(eventContract);
        eventNFT.claimNFT(participant2, proof2);

        assertTrue(eventNFT.claimed(participant2), "Participant2 should have claimed their NFT");
        assertEq(eventNFT.balanceOf(participant2), 1, "Participant2 should have 1 token");
    }

    function testClaimNFTAlreadyClaimed() public {
        vm.prank(eventContract);
        eventNFT.claimNFT(participant1, proof1);

        vm.expectRevert("EventNFT: You have already claimed your NFT");
        vm.prank(eventContract);
        eventNFT.claimNFT(participant1, proof1);
    }

    function testClaimNFTInvalidMerkleProof() public {
        address minter = address(999);
        bytes32[] memory tempLeafs = leafs;
        //replace the last leaf with the new address's hash who is not whitelisted.
        tempLeafs[1] = keccak256(abi.encodePacked(minter));

        bytes32[] memory invalidProof = getProof(tempLeafs, 1);

        vm.expectRevert("EventNFT: You are not an eligible participant");
        vm.prank(eventContract);
        eventNFT.claimNFT(minter, invalidProof);
    }

    function testOnlyEventContractCanClaim() public {
        // Try calling claimNFT from an address that's not the event contract
        vm.prank(address(999));
        vm.expectRevert("EventNFT: Only event contract can mint");
        eventNFT.claimNFT(participant1, proof1);
    }

    function testSetMerkleRoot() public {
        bytes32 newMerkleRoot = keccak256(abi.encodePacked(participant1, participant2)); // New Merkle root
        vm.prank(owner);
        eventNFT.setMerkleRoot(newMerkleRoot);

        assertEq(eventNFT.merkleRoot(), newMerkleRoot, "Merkle root should be updated");
    }

    function testSetEventContract() public {
        address newEventContract = address(999);
        vm.prank(owner);
        eventNFT.setEventContract(newEventContract);

        assertEq(eventNFT.eventContract(), newEventContract, "Event contract address should be updated");
    }

    function testOnlyOwnerCanSetEventContract() public {
        address newEventContract = address(999);
        vm.expectRevert();
        vm.prank(address(2));
        eventNFT.setEventContract(newEventContract);
    }
}
