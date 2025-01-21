// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventManager.sol";
import "../src/EventRewardManager.sol";
import "../src/interfaces/IWorldID.sol";

contract EventManagerTest is Test {
  EventManager private eventManager;
  EventRewardManager private rewardManager;

  address public owner;
  address public eventCreator;
  address public user1;
  address public user2;

  event ParticipantRegistered(uint256 eventId, address indexed participant);

  event BulkTokenRewardSet(
    uint256 indexed eventId, address[] indexed recipients, uint256[] amounts
  );

  address constant MOCK_REWARD_MANAGER = address(0x5678);
  address constant WORLD_ID_CONTRACT = address(0x1234);
  address constant MOCK_TOKEN = address(0x11123234);
  uint256 constant WORLD_ID_ROOT = 123_456_789;
  string constant APP_ID = "app_test";
  string constant ACTION_ID = "action_test";
  uint256 constant GROUP_ID = 1;

  event EventRegistered(uint256 id, string description, address indexed creator);
  event ParticipantRewardSet(
    uint256 indexed eventId,
    address indexed participant,
    address indexed tokenAddress,
    uint256 amount
  );

  function setUp() public {
    owner = address(this);
    user1 = address(0x1);
    user2 = address(0x2);
    eventCreator = address(0x3);
    eventManager = new EventManager(WORLD_ID_CONTRACT, WORLD_ID_ROOT, APP_ID, ACTION_ID, GROUP_ID);
    eventManager.setRewardManager(MOCK_REWARD_MANAGER);
  }

  function testEventManagerConstruction() public view {
    assertEq(address(eventManager.getWorldId()), address(WORLD_ID_CONTRACT));
    assertEq(eventManager.appId(), "appId");
    assertEq(eventManager.actionId(), "actionId");
  }

  // Unit Test for Create Events
  function testCreateEventSuccess() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory eventDescription = "This is a test event";
    uint256 eventTimestamp = block.timestamp + 1 days;

    // Act
    eventManager.createEvent(eventName, eventDescription, eventTimestamp);

    vm.expectEmit(true, true, true, true);
    emit EventRegistered(
      0, // eventId
      eventDescription,
      address(this)
    );

    // Assert
    EventManager.Event memory evt = eventManager.getEvent(0);
    assertEq(evt.id, 0);
    assertEq(evt.creator, address(this));
    assertEq(evt.description, eventDescription);
    assertEq(evt.name, eventName);
    assertEq(evt.timestamp, eventTimestamp);
  }

  function testGetAllEvents() public {
    // Use the createEvent function to add events
    eventManager.createEvent("Event One", "First Event", block.timestamp + 1 days);
    eventManager.createEvent("Event Two", "Second Event", block.timestamp + 2 days);

    EventManager.Event[] memory events = eventManager.getAllEvents();
    assertEq(events.length, 2);
    assertEq(events[0].description, "First Event");
    assertEq(events[1].description, "Second Event");
    assertEq(events[0].name, "Event One");
  }

  function testCreateEventFailsWhenNameIsEmpty() public {
    // Arrange
    string memory emptyName = "";
    string memory eventDescription = "This is a test event";
    uint256 eventTimestamp = block.timestamp + 1 days;

    // Act & Assert
    vm.expectRevert(bytes("Event name is required"));
    eventManager.createEvent(emptyName, eventDescription, eventTimestamp);
  }

  function testCreateEventFailsWhenDescriptionIsEmpty() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory emptyDescription = "";
    uint256 eventTimestamp = block.timestamp + 1 days;

    // Act & Assert
    vm.expectRevert(bytes("Description is required"));
    eventManager.createEvent(eventName, emptyDescription, eventTimestamp);
  }

  function testCreateEventFailsWhenTimestampIsNotFuture() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory eventDescription = "This is a test event";
    uint256 currentTime = block.timestamp;
    uint256 pastTimestamp = currentTime - 1;

    // Act
    vm.expectRevert(bytes("Timestamp must be in the future"));

    // Assert
    eventManager.createEvent(eventName, eventDescription, pastTimestamp);
  }

  function testRegisterParticipantSuccess() public {
    // Arrange
    uint256 nullifierHash = 12_345;
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
        "verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof
      ),
      abi.encode(true)
    );

    // Create a test event
    eventManager.createEvent("World ID Event", "Event Name", block.timestamp + 1 days);

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
    uint256 nullifierHash = 12_345;
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
        "verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof
      ),
      abi.encode(true)
    );

    eventManager.createEvent("World ID Event", "Event Name", block.timestamp + 1 days);

    // Act
    eventManager.registerParticipant(0, nullifierHash, proof);

    // Assert
    vm.expectRevert("Already registered as participant");
    eventManager.registerParticipant(0, nullifierHash, proof);
  }

  // Unit Test for Create Events
  function testCreateRewardSuccess() public {
    // Arrange
    string memory tokenName = "Test Event";
    string memory tokenSymbol = "This is a test event";
    uint256 supply = 1000;
    string memory uri = "dummy_uri";

    vm.mockCall(
      MOCK_REWARD_MANAGER,
      abi.encodeWithSignature(
        "createTokenReward(uint256,address,uint256,address,uint256)",
        0,
        eventCreator,
        IEventRewardManager.TokenType.USDC,
        MOCK_TOKEN,
        1_000_000
      ),
      abi.encode(true)
    );

    testCreateEventSuccess();

    // Act
    eventManager.createReward(
      0,
      tokenName,
      tokenSymbol,
      supply,
      uri,
      IEventRewardManager.TokenType.USDC,
      MOCK_TOKEN,
      1_000_000,
      "https://bonusbase.uri/"
    );

    // Assert
    EventManager.Event memory evt = eventManager.getEvent(0);
    assertEq(evt.rewardSet, true);
  }

  function testSetTokenRewardForParticipant() public {
    testCreateEventSuccess();

    // Register participant
    vm.prank(user1);
    uint256[8] memory proof;
    eventManager.registerParticipant(0, 12_345, proof);

    vm.mockCall(
      MOCK_REWARD_MANAGER,
      abi.encodeWithSignature(
        "distributeTokenReward(uint256,address,address,uint256)", 0, eventCreator, user1, 1_000_000
      ),
      abi.encode(true)
    );

    vm.expectEmit(true, true, false, true);
    emit ParticipantRewardSet(0, user1, eventCreator, 1_000_000);

    // Set reward
    vm.prank(eventCreator);
    eventManager.setTokenRewardForParticipant(0, user1, 1_000_000);
  }

  function testFailSetTokenRewardForNonParticipant() public {
    testCreateEventSuccess();

    eventManager.setTokenRewardForParticipant(0, user1, 1_000_000);
  }

  function testClaimReward() public {
    // Create event
    testCreateEventSuccess();

    mockUSDC.mint(address(mockRewardManager), REWARD_AMOUNT * 2);
    vm.prank(address(mockRewardManager));
    mockUSDC.approve(address(eventManager), type(uint256).max);

    // Register participant
    vm.prank(user1);
    uint256[8] memory proof;
    eventManager.registerParticipant(0, 12_345, proof);

    vm.prank(eventCreator);
    eventManager.setTokenRewardForParticipant(0, user1, REWARD_AMOUNT);

    uint256 userBal = mockUSDC.balanceOf(address(user1));

    // Claim reward
    vm.prank(user1);
    eventManager.claimReward(0, 54_321, proof);

    uint256 userAfter = mockUSDC.balanceOf(address(user1));
    assertEq(userAfter, userBal + REWARD_AMOUNT);
  }

  function testUpdateEventTokenReward() public {
    testCreateEventSuccess();

    uint256 creatorBal = mockUSDC.balanceOf(address(eventCreator));

    uint256 newRewardAmount = 200;
    vm.prank(eventCreator);
    eventManager.updateEventTokenReward(0, newRewardAmount);

    uint256 creatorAfter = mockUSDC.balanceOf(address(eventCreator));

    assertLt(creatorAfter, creatorBal);
  }

  function testBulkRewardDistribution() public {
    testCreateEventSuccess();

    // Register participants
    uint256[8] memory proof;

    vm.prank(user1);
    eventManager.registerParticipant(0, 12_345, proof);

    vm.prank(user2);
    eventManager.registerParticipant(0, 123_456, proof);

    // Setup bulk reward data
    address[] memory participants = new address[](2);
    participants[0] = user1;
    participants[1] = user2;

    uint256[] memory rewards = new uint256[](2);
    rewards[0] = REWARD_AMOUNT;
    rewards[1] = REWARD_AMOUNT;

    // Distribute rewards
    vm.prank(eventCreator);
    eventManager.updateEventTokenReward(0, 1000);

    vm.expectEmit(true, true, true, true);
    emit BulkTokenRewardSet(0, participants, rewards);

    vm.prank(eventCreator);
    eventManager.setBulkRewardsForParticipants(0, participants, rewards);
  }

  function testClaimNFTReward() public {
    testCreateNFTEvent();

    vm.prank(owner);
    eventManager.setEventNFTAddress(address(mockEventNFT));

    uint256[8] memory proof;
    vm.prank(user1);
    eventManager.registerParticipant(0, 12_345, proof);

    vm.prank(user1);

    (bool isClaimed, address caller, uint256 tokenId) =
      eventManager.claimNFTReward(0, 54_321, proof);

    assertTrue(isClaimed);
    assertEq(caller, user1);
    assertEq(mockEventNFT.ownerOf(tokenId), user1);
    assertTrue(mockEventNFT.hasClaimedNFT(user1));
  }

  function testClaimNFTBonusReward() public {
    testCreateNFTEvent();

    vm.prank(owner);
    eventManager.setEventNFTAddress(address(mockEventNFT));

    uint256[8] memory proof;
    vm.prank(user1);
    eventManager.registerParticipant(0, 12_345, proof);
    vm.prank(user2);
    eventManager.registerParticipant(0, 12_346, proof);

    vm.prank(user1);
    (bool isClaimed, address caller, uint256 tokenId) =
      eventManager.claimNFTReward(0, 54_321, proof);

    assertTrue(isClaimed);
    assertEq(caller, user1);
    assertEq(mockEventNFT.ownerOf(tokenId), user1);
    assertTrue(mockEventNFT.hasClaimedNFT(user1));
    assertTrue(mockEventNFT.hasClaimedBonusNFT(user1));
  }

  function testFailClaimNFTRewardForTokenEvent() public {
    testCreateEventSuccess();

    vm.prank(owner);
    eventManager.setEventNFTAddress(address(mockEventNFT));

    uint256[8] memory proof;
    vm.prank(user1);
    eventManager.registerParticipant(0, 12_345, proof);

    vm.prank(user1);

    (bool isClaimed, address caller, uint256 tokenId) =
      eventManager.claimNFTReward(0, 54_321, proof);

    assertTrue(isClaimed);
    assertEq(caller, user1);
    assertEq(mockEventNFT.ownerOf(tokenId), user1);
    assertTrue(mockEventNFT.hasClaimedNFT(user1));
  }

  function testGiveFirstParticipantTokenBonus() public {
    testCreateEventSuccess();

    // Register participant

    uint256[8] memory proof;
    vm.prank(user1);
    eventManager.registerParticipant(0, 12_345, proof);

    vm.prank(user2);
    eventManager.registerParticipant(0, 12_346, proof);

    // Set reward
    vm.startPrank(eventCreator);
    uint256 newRewardAmount = 200;
    eventManager.updateEventTokenReward(0, newRewardAmount);
    eventManager.setTokenRewardForParticipant(0, user1, REWARD_AMOUNT);
    eventManager.setTokenRewardForParticipant(0, user2, REWARD_AMOUNT);

    eventManager.giveFirstParticipantTokenBonus(0, BONUSTOKEN);
    vm.stopPrank();

    uint256 distributedReward = mockRewardManager.getUserTokenReward(0, address(user1));
    console.log(distributedReward);

    assertEq(distributedReward, REWARD_AMOUNT + 10);
  }
}
