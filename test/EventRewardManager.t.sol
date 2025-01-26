// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EventManager.sol";
import "../src/EventRewardManager.sol";
import "../src/EventNFT.sol";
import { MockWorldID } from "./mocks/MockWorldId.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";

contract EventRewardManagerTest is Test {
  EventManager public eventManager;
  EventRewardManager public rewardManager;
  EventNFT public eventNFT;
  MockWorldID public mockWorldID;
  MockERC20 public usdcToken;
  MockERC20 public wldToken;

  uint256 public FIRST_PARTICIPANT_BONUS;

  address public owner;
  address public participant;
  address public unverifiedUser;
  address public user1;
  address public user2;
  address public user3;
  address public eventCreator;

  uint256 eventId;
  uint256 rewardAmount;

  function setUp() public {
    owner = address(this);
    participant = address(0x1337);
    user1 = address(0x15);
    user2 = address(0x210);
    user3 = address(0x315);
    eventCreator = address(0x348);

    // Deploy the mock contract and set the valid root
    mockWorldID = new MockWorldID();
    mockWorldID.setValidRoot(123_456_789); // Set the expected root value

    usdcToken = new MockERC20("USDC", "USDC", 6);
    wldToken = new MockERC20("WLD", "WLD", 18);

    eventManager = new EventManager(address(mockWorldID), 123_456_789, "appId", "actionId", 1234);
    rewardManager = new EventRewardManager(address(eventManager));
    eventManager.setRewardManager(address(rewardManager));

    eventNFT = new EventNFT(
      "EventNFT", "ENFT", 100, "https://base.uri/", "https://bonusbase.uri/", address(eventManager)
    );

    // Mint and Approve Tokens
    uint256 _RewardAmount = 100 * 10 ** 6; // 100 USDC

    FIRST_PARTICIPANT_BONUS = 10 * 10 ** 6;

    // Mint USDC to eventCreator and approve EventManager and RewardManager
    usdcToken.mint(eventCreator, 1_000_000_000 * 1e6);

    // Act as eventCreator to approve tokens
    vm.startPrank(eventCreator);
    usdcToken.approve(address(eventManager), 1_000_000_000 * 1e6); // Approve EventManager
    usdcToken.approve(address(rewardManager), 1_000_000_000 * 1e6); // Approve RewardManager
    vm.stopPrank();

    // Mint tokens to EventManager (if it needs balance)
    usdcToken.mint(address(eventManager), _RewardAmount);
    vm.prank(address(eventManager));
    usdcToken.approve(address(rewardManager), _RewardAmount);

    // Create Event
    vm.prank(eventCreator);
    eventId = 0;
    eventManager.createEvent("Devcon 2025", "Test Event", block.timestamp + 1 days);

    vm.prank(participant);
    eventManager.registerParticipant(
      eventId,
      12_344,
      [
        uint256(1),
        uint256(2),
        uint256(3),
        uint256(4),
        uint256(5),
        uint256(6),
        uint256(7),
        uint256(8)
      ]
    );

    vm.prank(user1);
    eventManager.registerParticipant(
      eventId,
      12_345,
      [
        uint256(1),
        uint256(2),
        uint256(3),
        uint256(4),
        uint256(5),
        uint256(6),
        uint256(7),
        uint256(8)
      ]
    );

    vm.prank(user2);
    eventManager.registerParticipant(
      eventId,
      12_346,
      [
        uint256(1),
        uint256(2),
        uint256(3),
        uint256(4),
        uint256(5),
        uint256(6),
        uint256(7),
        uint256(8)
      ]
    );

    vm.prank(user3);
    eventManager.registerParticipant(
      eventId,
      12_347,
      [
        uint256(1),
        uint256(2),
        uint256(3),
        uint256(4),
        uint256(5),
        uint256(6),
        uint256(7),
        uint256(8)
      ]
    );

    // Mint tokens to the test contract and approve the reward manager
    rewardAmount = 1000 * 10 ** 6; // 1000 USDC
    usdcToken.mint(address(this), rewardAmount);
    usdcToken.approve(address(rewardManager), rewardAmount);
  }

  function testCreateTokenReward() public {
    // Test event emitted as expected
    vm.expectEmit(true, true, true, true);
    emit EventRewardManager.RewardCreated(
      eventId, eventCreator, address(usdcToken), IEventRewardManager.TokenType.USDC, rewardAmount
    );

    vm.prank(address(eventManager));
    // Create event token reward
    rewardManager.createTokenReward(
      eventId, eventCreator, IEventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Verify created reward amount
    (
      address creator,
      address tokenAddress,
      EventRewardManager.TokenType tokenType,
      uint256 eventRewardAmount,
      uint256 createdAt,
      bool isCancelled,
      uint256 claimedAmount
    ) = rewardManager.eventTokenRewards(eventId);

    assert(creator == eventCreator);
    assert(tokenType == IEventRewardManager.TokenType.USDC);
    assert(tokenAddress == address(usdcToken));
    assert(eventRewardAmount == rewardAmount);
    assert(createdAt > 0);
    assert(!isCancelled);
    assertEq(claimedAmount, 0);
  }

  function testCreateTokenRewardZeroAddress() public {
    // Attempt to create a token reward with a zero address
    vm.expectRevert("Zero token address detected");
    vm.prank(address(eventManager));
    rewardManager.createTokenReward(
      eventId, eventCreator, IEventRewardManager.TokenType.USDC, address(0), rewardAmount
    );
  }

  function testCreateTokenRewardZeroAmount() public {
    // Attempt to create a token reward with a zero reward amount
    vm.expectRevert("Zero amount detected");
    vm.prank(address(eventManager));
    rewardManager.createTokenReward(
      eventId, eventCreator, IEventRewardManager.TokenType.USDC, address(usdcToken), 0
    );
  }

  function testCreateTokenRewardInvalidTokenType() public {
    // Attempt to create a token reward with an invalid token type
    vm.expectRevert("Invalid token type");
    vm.prank(address(eventManager));
    rewardManager.createTokenReward(
      eventId, eventCreator, IEventRewardManager.TokenType.NFT, address(usdcToken), rewardAmount
    );
  }

  function testCreateTokenRewardEventDoesNotExist() public {
    uint256 invalidEventId = 420;

    // Attempt to create a token reward for a non-existent event
    vm.expectRevert("Event does not exist");
    vm.prank(address(eventManager));
    rewardManager.createTokenReward(
      invalidEventId,
      eventCreator,
      IEventRewardManager.TokenType.USDC,
      address(usdcToken),
      rewardAmount
    );
  }

  function testUpdateTokenReward() public {
    uint256 additionalReward = 500 * 10 ** 6;

    vm.prank(address(eventManager));
    // Create initial event token reward
    rewardManager.createTokenReward(
      eventId, eventCreator, IEventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Mint more tokens to update event reward
    usdcToken.mint(eventCreator, additionalReward);
    usdcToken.approve(address(rewardManager), additionalReward);

    // Test event emitted as expected
    vm.expectEmit(true, true, true, true);
    emit EventRewardManager.TokenRewardUpdated(eventId, eventCreator, additionalReward);
    vm.prank(address(eventManager));
    rewardManager.updateTokenReward(eventId, eventCreator, additionalReward);

    // Verify the updated reward amount
    (
      address creator,
      address tokenAddress,
      EventRewardManager.TokenType tokenType,
      uint256 eventRewardAmount,
      ,
      ,
    ) = rewardManager.eventTokenRewards(eventId);

    assert(creator == eventCreator);
    assert(tokenAddress == address(usdcToken));
    assert(tokenType == IEventRewardManager.TokenType.USDC);
    assert(eventRewardAmount == rewardAmount + additionalReward);
  }

  function testCreateNFTReward() public {
    string memory tokenName = "Test Event";
    string memory tokenSymbol = "This is a test event";
    uint256 supply = 1000;
    string memory uri = "https://base.uri/";
    string memory bonus_uri = "https://bonusbase.uri/";

    // Test event emitted as expected
    vm.expectEmit(true, true, true, false);
    emit EventRewardManager.RewardCreated(
      eventId, eventCreator, address(usdcToken), IEventRewardManager.TokenType.NFT, 1
    );

    vm.prank(address(eventManager));
    // Create event token reward
    rewardManager.createNFTReward(
      eventId,
      eventCreator,
      IEventRewardManager.TokenType.NFT,
      tokenName,
      tokenSymbol,
      supply,
      uri,
      bonus_uri
    );

    // Verify created reward amount
    (
      address creator,
      ,
      EventRewardManager.TokenType tokenType,
      uint256 eventRewardAmount,
      uint256 createdAt,
      bool isCancelled,
      uint256 claimedAmount
    ) = rewardManager.eventTokenRewards(eventId);

    assert(creator == eventCreator);
    assert(tokenType == IEventRewardManager.TokenType.NFT);
    assert(eventRewardAmount == 1);
    assert(createdAt > 0);
    assert(!isCancelled);
    assertEq(claimedAmount, 0);
  }

  function testUpdateTokenRewardOnlyEventManager() public {
    uint256 additionalReward = 500 * 10 ** 6;

    testCreateTokenReward();

    // Attempt to update the token reward from a different address
    address nonManager = address(0x666);
    vm.expectRevert("Only event manager allowed");
    vm.prank(nonManager);
    rewardManager.updateTokenReward(eventId, eventCreator, additionalReward);
  }

  function testUpdateTokenRewardEventDoesNotExist() public {
    uint256 invalidEventId = 999;
    uint256 additionalReward = 500 * 10 ** 6;

    testCreateTokenReward();

    // Attempt to update the token reward for a non-existent event
    vm.prank(address(eventManager));
    vm.expectRevert("Event does not exist");
    rewardManager.updateTokenReward(invalidEventId, eventCreator, additionalReward);
  }

  function testDistributeTokenReward() public {
    testCreateTokenReward();

    vm.prank(address(eventManager));

    rewardManager.distributeTokenReward(eventId, eventCreator, participant, rewardAmount);

    uint256 distributedReward = rewardManager.getUserTokenReward(eventId, participant);
    assertEq(distributedReward, rewardAmount);
  }

  function testRewardDistributedEvent() public {
    testCreateTokenReward();

    vm.prank(address(eventManager));

    vm.expectEmit(true, true, false, true);
    emit EventRewardManager.TokenRewardDistributed(eventId, participant, rewardAmount);

    rewardManager.distributeTokenReward(eventId, eventCreator, participant, rewardAmount);
  }

  function testDistributeTokenRewardEventDoesNotExist() public {
    uint256 invalidEventId = 1111;
    uint256 participantReward = 100 * 10 ** 6;

    testCreateTokenReward();

    vm.prank(address(eventManager));
    // Attempt to distribute tokens for an event that does not exist
    vm.expectRevert("Event does not exist");
    rewardManager.distributeTokenReward(
      invalidEventId, eventCreator, participant, participantReward
    );
  }

  function testDistributeTokenRewardInsufficientRewardAmount() public {
    uint256 participantReward = 1100 * 10 ** 6;

    testCreateTokenReward();

    vm.prank(address(eventManager));

    // Attempt to distribute more tokens than available in contract
    vm.expectRevert("Insufficient reward amount");
    rewardManager.distributeTokenReward(eventId, eventCreator, participant, participantReward);
  }

  function testGetUserTokenRewardInvalidAddress() public {
    testCreateTokenReward();

    address zeroAddress = address(0);

    vm.prank(zeroAddress);
    vm.expectRevert("Zero Address Detected");

    rewardManager.getUserTokenReward(eventId, zeroAddress);
  }

  function testClaimTokenReward() public {
    testDistributeTokenReward();

    vm.prank(address(eventManager));
    rewardManager.claimTokenReward(eventId, participant);

    uint256 userBalance = usdcToken.balanceOf(participant);
    assertEq(userBalance, rewardAmount);

    uint256 remainingReward = rewardManager.getUserTokenReward(eventId, participant);
    assertEq(remainingReward, 0);
  }

  function testRewardClaimedEvent() public {
    testDistributeTokenReward();

    vm.expectEmit(true, true, false, true);
    emit EventRewardManager.TokenRewardClaimed(eventId, participant, rewardAmount);

    vm.prank(address(eventManager));
    rewardManager.claimTokenReward(eventId, participant);
  }

  function testClaimTokenRewardInvalidParticipant() public {
    testDistributeTokenReward();

    vm.prank(address(eventManager));
    vm.expectRevert("Not a registered participant");
    rewardManager.claimTokenReward(eventId, unverifiedUser);
  }

  function testFailDoubleClaimTokenReward() public {
    testDistributeTokenReward();

    vm.prank(address(eventManager));
    rewardManager.claimTokenReward(eventId, unverifiedUser);
    vm.expectRevert("Reward already claimed");
    rewardManager.claimTokenReward(eventId, unverifiedUser);
    vm.stopPrank();
  }

  function testClaimTokenRewardInvalidEventId() public {
    vm.prank(address(eventManager));
    vm.expectRevert("Event does not exist");
    rewardManager.claimTokenReward(999, participant);
  }

  function testDistributeMultipleTokenRewards() public {
    testCreateTokenReward();

    address[] memory recipients = new address[](3);
    recipients[0] = user1;
    recipients[1] = user2;
    recipients[2] = user3;

    uint256[] memory rewards = new uint256[](3);
    rewards[0] = 5;
    rewards[1] = 6;
    rewards[2] = 7;

    vm.prank(address(eventManager));
    rewardManager.distributeMultipleTokenRewards(eventId, eventCreator, recipients, rewards);

    assertEq(rewardManager.getUserTokenReward(eventId, user1), 5, "User1 reward incorrect");
    assertEq(rewardManager.getUserTokenReward(eventId, user2), 6, "User2 reward incorrect");
    assertEq(rewardManager.getUserTokenReward(eventId, user3), 7, "User3 reward incorrect");

    (,,, uint256 remainingReward,,,) = rewardManager.eventTokenRewards(eventId);
    assertEq(remainingReward, rewardAmount - 18, "Remaining reward incorrect");
  }

  function testGetMultipleDistributedTokenRewards() public {
    testDistributeMultipleTokenRewards();

    address[] memory recipients = new address[](3);
    recipients[0] = user1;
    recipients[1] = user2;
    recipients[2] = user3;

    uint256[] memory distributedRewards =
      rewardManager.getMultipleDistributedTokenRewards(eventId, recipients);

    assertEq(distributedRewards.length, 3, "Incorrect number of rewards returned");
    assertEq(distributedRewards[0], 5, "User1 reward incorrect");
    assertEq(distributedRewards[1], 6, "User2 reward incorrect");
    assertEq(distributedRewards[2], 7, "User3 reward incorrect");
  }

  function testDistributeMultipleTokenRewardsInsufficientReward() public {
    testCreateTokenReward();

    address[] memory recipients = new address[](3);
    recipients[0] = user1;
    recipients[1] = user2;
    recipients[2] = user3;

    uint256[] memory rewards = new uint256[](3);
    rewards[0] = 1_000_000_000;
    rewards[1] = 1_000_000_000;
    rewards[2] = 1_000_000_000;

    vm.expectRevert("Insufficient reward amount");
    vm.prank(address(eventManager));
    rewardManager.distributeMultipleTokenRewards(eventId, eventCreator, recipients, rewards);
  }

  function testDistributeMultipleTokenRewardsArrayMismatch() public {
    testCreateTokenReward();

    address[] memory recipients = new address[](3);
    recipients[0] = user1;
    recipients[1] = user2;
    recipients[2] = user3;

    uint256[] memory rewards = new uint256[](2);
    rewards[0] = 5;
    rewards[1] = 5;

    vm.expectRevert("Arrays length mismatch");
    vm.prank(address(eventManager));
    rewardManager.distributeMultipleTokenRewards(eventId, eventCreator, recipients, rewards);
  }

  function testDistributedMultipleTokenRewardsEmptyArray() public {
    testCreateTokenReward();

    address[] memory emptyRecipients = new address[](0);
    uint256[] memory emptyRewards = new uint256[](0);

    vm.expectRevert("Empty arrays");
    vm.prank(address(eventManager));
    rewardManager.distributeMultipleTokenRewards(
      eventId, eventCreator, emptyRecipients, emptyRewards
    );
  }

  function testGetMultipleDistributedTokenRewardsEmptyArray() public view {
    address[] memory emptyRecipients = new address[](0);
    uint256[] memory emptyRewards =
      rewardManager.getMultipleDistributedTokenRewards(eventId, emptyRecipients);

    assertEq(emptyRewards.length, 0, "Empty array should be returned for empty input");
  }
}
