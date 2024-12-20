// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/EventManager.sol";
import "../src/EventRewardManager.sol";

contract EventRewardManagerTest is Test {
  EventManager public eventManager;
  EventRewardManager public rewardManager;
  MockERC20 public usdcToken;
  MockERC20 public wldToken;

  address public owner;
  address public participant;
  uint256 eventId;
  uint256 rewardAmount;

  function setUp() public {
    owner = address(this);
    participant = address(0x1337);

    usdcToken = new MockERC20("USDC", "USDC", 6);
    wldToken = new MockERC20("WLD", "WLD", 18);

    eventManager =
      new EventManager(address(0x1234), 123_456_789, address(0x5678), "appId", "actionId");
    rewardManager = new EventRewardManager(address(eventManager));

    // Create event for testing
    eventId = 0;
    eventManager.createEvent("Devcon 2025", "Test Event", block.timestamp + 1 days, "USDC");

    // Mint tokens to the test contract and approve the reward manager
    rewardAmount = 1000 * 10 ** 6; // 1000 USDC
    usdcToken.mint(address(this), rewardAmount);
    usdcToken.approve(address(rewardManager), rewardAmount);
  }

  function testCreateTokenReward() public {
    // Test event emitted as expected
    vm.expectEmit(true, true, true, true);
    emit EventRewardManager.TokenRewardCreated(
      eventId, address(this), address(usdcToken), EventRewardManager.TokenType.USDC, rewardAmount
    );

    // Create event token reward
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Verify created reward amount
    (
      address manager,
      address tokenAddress,
      EventRewardManager.TokenType tokenType,
      uint256 eventRewardAmount
    ) = rewardManager.eventTokenRewards(eventId);

    assert(manager == owner);
    assert(tokenType == EventRewardManager.TokenType.USDC);
    assert(tokenAddress == address(usdcToken));
    assert(eventRewardAmount == rewardAmount);
  }

  function testCreateTokenRewardZeroAddress() public {
    // Attempt to create a token reward with a zero address
    vm.expectRevert("Zero token address detected");
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(0), rewardAmount
    );
  }

  function testCreateTokenRewardZeroAmount() public {
    // Attempt to create a token reward with a zero reward amount
    vm.expectRevert("Zero amount detected");
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), 0
    );
  }

  function testCreateTokenRewardInvalidTokenType() public {
    // Attempt to create a token reward with an invalid token type
    vm.expectRevert("Invalid token type");
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.NFT, address(usdcToken), rewardAmount
    );
  }

  function testCreateTokenRewardEventDoesNotExist() public {
    uint256 invalidEventId = 420;

    // Attempt to create a token reward for a non-existent event
    vm.expectRevert("Event does not exist");
    rewardManager.createTokenReward(
      invalidEventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );
  }

  function testUpdateTokenReward() public {
    uint256 additionalReward = 500 * 10 ** 6;

    // Create initial event token reward
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Mint more tokens to update event reward
    usdcToken.mint(address(this), additionalReward);
    usdcToken.approve(address(rewardManager), additionalReward);

    // Test event emitted as expected
    vm.expectEmit(true, true, true, true);
    emit EventRewardManager.TokenRewardUpdated(eventId, address(this), additionalReward);
    rewardManager.updateTokenReward(eventId, additionalReward);

    // Verify the updated reward amount
    (
      address manager,
      address tokenAddress,
      EventRewardManager.TokenType tokenType,
      uint256 eventRewardAmount
    ) = rewardManager.eventTokenRewards(eventId);

    assert(manager == owner);
    assert(tokenAddress == address(usdcToken));
    assert(tokenType == EventRewardManager.TokenType.USDC);
    assert(eventRewardAmount == rewardAmount + additionalReward);
  }

  function testUpdateTokenRewardOnlyEventManager() public {
    uint256 additionalReward = 500 * 10 ** 6;

    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Attempt to update the token reward from a different address
    address nonManager = address(0x666);
    vm.prank(nonManager);
    vm.expectRevert("Only event manager allowed");
    rewardManager.updateTokenReward(eventId, additionalReward);
  }

  function testUpdateTokenRewardEventDoesNotExist() public {
    uint256 invalidEventId = 999;
    uint256 additionalReward = 500 * 10 ** 6;

    // Attempt to update the token reward for a non-existent event
    vm.expectRevert("Event does not exist");
    rewardManager.updateTokenReward(invalidEventId, additionalReward);
  }

  function testDistributeTokenReward() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );
    rewardManager.distributeTokenReward(eventId, participant, rewardAmount);

    uint256 distributedReward = rewardManager.getUserTokenReward(eventId, participant);
    assertEq(distributedReward, rewardAmount);
  }

  function testDistributeTokenRewardEventDoesNotExist() public {
    uint256 invalidEventId = 1111;
    uint256 participantReward = 100 * 10 ** 6;

    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Attempt to distribute tokens for an event that does not exist
    vm.expectRevert("Event does not exist");
    rewardManager.distributeTokenReward(invalidEventId, participant, participantReward);
  }

  function testDistributeTokenRewardInsufficientRewardAmount() public {
    uint256 participantReward = 1100 * 10 ** 6;

    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Attempt to distribute more tokens than available in contract
    vm.expectRevert("Insufficient reward amount");
    rewardManager.distributeTokenReward(eventId, participant, participantReward);
  }

  function testGetUserTokenReward() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    rewardManager.distributeTokenReward(eventId, participant, rewardAmount);

    assertEq(rewardManager.getUserTokenReward(eventId, participant), rewardAmount);
  }

  function testGetUserTokenRewardInvalidAddress() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    address zeroAddress = address(0);

    vm.prank(zeroAddress);
    vm.expectRevert("Zero Address Detected");

    rewardManager.getUserTokenReward(eventId, zeroAddress);
  }

  function testGetUserTokenRewardInvalidEventId() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    uint256 invalidEventId = 5;

    vm.prank(participant);
    vm.expectRevert("Event does not exist");

    rewardManager.getUserTokenReward(invalidEventId, participant);
  }

  function testClaimTokenReward() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );
    rewardManager.distributeTokenReward(eventId, participant, rewardAmount);

    vm.prank(participant);
    rewardManager.claimTokenReward(eventId);

    uint256 userBalance = usdcToken.balanceOf(participant);
    assertEq(userBalance, rewardAmount);

    uint256 remainingReward = rewardManager.getUserTokenReward(eventId, participant);
    assertEq(remainingReward, 0);
  }

  function testFailDoubleClaimTokenReward() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );
    rewardManager.distributeTokenReward(eventId, participant, rewardAmount);

    vm.startPrank(participant);
    rewardManager.claimTokenReward(eventId);
    vm.expectRevert("Reward already claimed");
    rewardManager.claimTokenReward(eventId);
    vm.stopPrank();
  }

  function testClaimTokenRewardInvalidEventId() public {
    vm.prank(participant);
    vm.expectRevert("Event does not exist");
    rewardManager.claimTokenReward(999);
  }
}

// Mock ERC20 Token for Testing
contract MockERC20 {
  mapping(address => uint256) public balanceOf;
  mapping(address => mapping(address => uint256)) public allowance;

  string public name;
  string public symbol;
  uint8 public decimals;
  uint256 public totalSupply;

  constructor(string memory _name, string memory _symbol, uint8 _decimals) {
    name = _name;
    symbol = _symbol;
    decimals = _decimals;
  }

  function mint(address to, uint256 amount) public {
    balanceOf[to] += amount;
    totalSupply += amount;
  }

  function transfer(address recipient, uint256 amount) public returns (bool) {
    require(balanceOf[msg.sender] >= amount, "Insufficient balance");
    balanceOf[msg.sender] -= amount;
    balanceOf[recipient] += amount;
    return true;
  }

  function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
    require(balanceOf[sender] >= amount, "Insufficient balance");
    require(allowance[sender][msg.sender] >= amount, "Insufficient allowance");

    balanceOf[sender] -= amount;
    balanceOf[recipient] += amount;
    allowance[sender][msg.sender] -= amount;

    return true;
  }

  function approve(address spender, uint256 amount) public returns (bool) {
    allowance[msg.sender][spender] = amount;
    return true;
  }
}
