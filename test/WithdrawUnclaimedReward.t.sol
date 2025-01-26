// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";

import "./EventRewardManager.t.sol";

contract WithdrawUnclaimedReward is EventRewardManagerTest {
  // Function to test withdraw unclaim rewards
  function testWithdrawUnclaimedRewards() public {
    //Create a token reward
    testCreateTokenReward();

    //Fast forward time
    vm.warp(block.timestamp + 31 days);

    uint256 balanceBefore = usdcToken.balanceOf(eventCreator);
    vm.prank(address(eventManager));
    rewardManager.withdrawUnclaimedRewards(eventId, eventCreator);
    uint256 balanceAfter = usdcToken.balanceOf(eventCreator);

    assertEq(balanceAfter - balanceBefore, rewardAmount);

    (,,, uint256 eventRewardAmount,, bool isCancelled, uint256 claimedAmount) =
      rewardManager.eventTokenRewards(eventId);

    assertEq(eventRewardAmount, 0, "Reward amount should be 0 after full withdrawal");
    assertTrue(isCancelled, "Event should be cancelled after full withdrawal");
    assertEq(claimedAmount, 0, "Claimed amount should remain 0");
  }

  // Function to test withdraw before the limited time
  function testWithdrawBeforeTimeout() public {
    //Create a token reward
    testCreateTokenReward();

    vm.expectRevert("Withdrawal timeout not reached");
    vm.prank(address(eventManager));
    rewardManager.withdrawUnclaimedRewards(eventId, eventCreator);
  }

  // Function to test partial withdraw unclaimed rewards
  function testWithdrawUnclaimedRewardsPartial() public {
    //Create a token reward
    testCreateTokenReward();

    uint256 claimAmount = rewardAmount / 2;
    vm.prank(address(eventManager));
    rewardManager.distributeTokenReward(eventId, eventCreator, participant, claimAmount);

    // Fast forward time
    vm.warp(block.timestamp + 31 days);

    uint256 initialBalance = usdcToken.balanceOf(address(eventCreator));

    // Fast forward time
    vm.warp(block.timestamp + 31 days);
    vm.prank(address(eventManager));
    rewardManager.withdrawUnclaimedRewards(eventId, address(eventCreator));

    uint256 finalBalance = usdcToken.balanceOf(address(eventCreator));

    assertEq(
      finalBalance - initialBalance, rewardAmount - claimAmount, "Incorrect withdrawal amount"
    );

    (,,, uint256 eventRewardAmount,, bool isCancelled,) = rewardManager.eventTokenRewards(eventId);

    assertEq(eventRewardAmount, 0, "Reward amount should be 0 after full withdrawal");
    assertTrue(isCancelled, "Event should be cancelled after full withdrawal");
  }

  // Function to test withdraw unclaim rewards for someone who isn't the event manager
  function testWithdrawUnclaimedRewardsNonManager() public {
    //Create a token reward
    testCreateTokenReward();

    // Fast forward time
    vm.warp(block.timestamp + 31 days);

    address nonManager = address(0x1234);
    vm.prank(nonManager);
    vm.expectRevert("Only event manager allowed");
    rewardManager.withdrawUnclaimedRewards(eventId, eventCreator);
  }
}
