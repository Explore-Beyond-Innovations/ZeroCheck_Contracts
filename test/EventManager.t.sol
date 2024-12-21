// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/EventManager.sol";
import "../src/EventNFT.sol";
import "../src/interfaces/IWorldID.sol";
import { Merkle } from "murky/src/Merkle.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract MockWorldID is IWorldID {
  function verifyProof(
    uint256 root,
    uint256 nullifierHash,
    address signal,
    string memory appId,
    string memory actionId,
    uint256[8] memory proof
  )
    external
    pure
    override
    returns (bool)
  {
    return true; // Always returns true for testing purposes
  }
}

contract MockBonusNFT is ERC721 {
  constructor() ERC721("MockBonusNFT", "MNFT") { }

  function mint(address to, uint256 tokenId) public {
    _mint(to, tokenId);
  }
}

contract MockERC20 is ERC20 {
  constructor() ERC20("MockToken", "MTK") {
    _mint(msg.sender, 1_000_000 ether);
  }

  function mint(address to, uint256 amount) public {
    _mint(to, amount);
  }
}

contract EventManagerTest is Test, Merkle {
  EventManager private eventManager;
  EventNFT private eventNFT;
  MockWorldID private worldId;
  MockERC20 private token;
  MockBonusNFT private mockNFT;
  bytes32 private merkleRoot;

  address private rewardContract;
  address private creator = address(0x123);
  address private participant = address(0x456);
  address private firstRegistrant = address(0x789);
  address private tokenAddress = address(0x898);
  address private otherUser = address(0x899);
  string private appId = "app-id";
  string private actionId = "action-id";

  // Sample Merkle Tree for testing
  bytes32[] private proof_1;
  bytes32[] private proof_2;
  bytes32[] private leafs;

  function setUp() public {
    worldId = new MockWorldID();
    token = new MockERC20();

    leafs.push(keccak256(abi.encodePacked(participant)));
    leafs.push(keccak256(abi.encodePacked(firstRegistrant)));

    merkleRoot = getRoot(leafs);
    proof_1 = getProof(leafs, 0);
    proof_2 = getProof(leafs, 1);

    rewardContract = address(this);
    eventManager = new EventManager(IWorldID(address(worldId)), rewardContract, appId, actionId);

    eventNFT = new EventNFT(
      "EventNFT",
      "ENFT",
      1000,
      "https://example.com/metadata/",
      address(eventManager),
      address(this)
    );

    // Deploy MockNFT contract and mint tokens
    mockNFT = new MockBonusNFT();
    mockNFT.mint(address(eventManager), 1);
    mockNFT.mint(address(eventManager), 2);
    mockNFT.mint(address(eventManager), 3);
  }

  function testCreateEventFailsWhenNameIsEmpty() public {
    vm.expectRevert("Event name is required");

    eventManager.createEvent(
      "", // Empty name
      "Valid description",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );
  }

  function testCreateEventFailsWhenDescriptionIsEmpty() public {
    vm.expectRevert("Description is required");

    eventManager.createEvent(
      "Valid Name",
      "", // Empty description
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );
  }

  function testCreateEventFailsWhenTimestampIsInPast() public {
    vm.expectRevert("Timestamp must be in the future");

    eventManager.createEvent(
      "Valid Name",
      "Valid description",
      block.timestamp - 1, // Timestamp in the past
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );
  }

  function testCreateEventFailsWhenTokenAddressIsZeroForTokenReward() public {
    vm.expectRevert("Enter valid token Address");

    eventManager.createEvent(
      "Valid Name",
      "Valid description",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN, // Reward type is TOKEN
      address(0), // Invalid token address
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );
  }

  function testCreateEventFailsWhenTokenAddressIsZeroForNFTReward() public {
    vm.expectRevert("Enter valid token Address");

    eventManager.createEvent(
      "Valid Name",
      "Valid description",
      block.timestamp + 1 days,
      EventManager.RewardType.NFT, // Reward type is NFT
      address(0), // Invalid token address
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );
  }

  function testCreateEventFailsWhenEventNFTAddressIsZero() public {
    vm.expectRevert("Invalid event NFT contract.");

    eventManager.createEvent(
      "Valid Name",
      "Valid description",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(0) // Invalid event NFT contract address
    );
  }

  function testCreateEvent() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    EventManager.Event memory eventDetails = eventManager.getEvent(0);
    assertEq(eventDetails.creator, creator);
    assertEq(eventDetails.name, "Test Event");
    assertEq(uint256(eventDetails.rewardType), uint256(EventManager.RewardType.TOKEN));
  }

  function testRegisterParticipant() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    vm.prank(participant);
    eventManager.registerParticipant(eventId, root, nullifierHash, proof);

    bool isRegistered = eventManager.isParticipant(eventId, participant);
    assertTrue(isRegistered);
  }

  function testRegisterParticipantFailsWhenEventStarted() public {
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;

    vm.warp(block.timestamp + 2 days); // Advance time by 2 days

    vm.expectRevert("Event has already started");
    vm.prank(participant);
    eventManager.registerParticipant(eventId, root, nullifierHash, proof);
  }

  function testClaimRewardToken() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    vm.prank(participant);
    eventManager.registerParticipant(eventId, root, nullifierHash, proof);

    token.mint(address(eventManager), 100 ether);

    vm.prank(participant);
    eventManager.claimReward(eventId, nullifierHash, new bytes32[](0));

    assertEq(token.balanceOf(participant), 12 ether); //Only participant and first participant
  }

  function testClaimRewardTokenForOtherParticipant() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root1 = 0x123;
    uint256 root2 = 0x456;
    uint256 nullifierHash1 = 1;
    uint256 nullifierHash2 = 2;
    uint256[8] memory proof1;
    uint256[8] memory proof2;

    token.mint(address(eventManager), 100 ether);

    // First Registrant
    vm.prank(firstRegistrant);
    eventManager.registerParticipant(eventId, root1, nullifierHash1, proof1);
    bool isRegistered1 = eventManager.isParticipant(eventId, firstRegistrant);

    vm.prank(firstRegistrant);
    eventManager.claimReward(eventId, nullifierHash1, new bytes32[](0));

    // Second Participant
    vm.prank(participant);
    eventManager.registerParticipant(eventId, root2, nullifierHash2, proof2);
    bool isRegistered2 = eventManager.isParticipant(eventId, participant);

    vm.prank(participant);
    eventManager.claimReward(eventId, nullifierHash2, new bytes32[](1));

    // Assert Correct Balances
    assertEq(isRegistered1, true);
    assertEq(isRegistered2, true);
    assertEq(token.balanceOf(firstRegistrant), 12 ether);
    assertEq(token.balanceOf(participant), 10 ether);
  }

  function testClaimRewardNFT() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.NFT,
      address(mockNFT),
      0,
      0,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    bytes32 participantHash = keccak256(abi.encodePacked(participant));
    eventNFT.setMerkleRoot(merkleRoot);

    vm.prank(participant);
    eventManager.registerParticipant(eventId, root, nullifierHash, proof);

    vm.prank(participant);
    eventManager.claimReward(eventId, nullifierHash, proof_1);

    assertEq(eventNFT.ownerOf(0), participant);
    assertEq(mockNFT.ownerOf(1), participant); //Bonus NFT Reward as First Participant
  }

  function testCannotClaimRewardTwice() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    vm.prank(participant);
    eventManager.registerParticipant(eventId, root, nullifierHash, proof);

    token.mint(address(eventManager), 100 ether);

    vm.prank(participant);
    eventManager.claimReward(eventId, nullifierHash, new bytes32[](0));

    vm.expectRevert("Reward already claimed");
    vm.prank(participant);
    eventManager.claimReward(eventId, nullifierHash, new bytes32[](0));
  }

  function testCannotAllowUnregisteredUserClaimReward() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    vm.prank(participant);
    eventManager.registerParticipant(eventId, root, nullifierHash, proof);

    token.mint(address(eventManager), 100 ether);

    vm.expectRevert("Not a participant");
    vm.prank(otherUser);
    eventManager.claimReward(eventId, nullifierHash, new bytes32[](0));
  }

  function testOnlyCreatorCanSetMerkleRoot() public {
    vm.prank(creator);
    eventManager.createEvent(
      "Test Event",
      "This is a test event",
      block.timestamp + 1 days,
      EventManager.RewardType.TOKEN,
      address(token),
      10 ether,
      2 ether,
      1,
      address(eventNFT)
    );

    uint256 eventId = 0;
    uint256 root = 0;
    uint256 nullifierHash = 0;
    uint256[8] memory proof;

    token.mint(address(eventManager), 100 ether);

    vm.expectRevert("Only event creator can set root");
    vm.prank(participant);
    eventManager.setEventMerkleRoot(eventId, merkleRoot);
  }
}
