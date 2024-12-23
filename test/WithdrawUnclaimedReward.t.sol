// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./EventRewardManager.t.sol";

contract WithdrawUnclaimedReward is EventRewardManagerTest {
  // Function to test withdraw unclaim rewards
  function testWithdrawUnclaimedRewards() public {
    //Create a token reward
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    //Fast forward time
    vm.warp(block.timestamp + 31 days);

    uint256 balanceBefore = usdcToken.balanceOf(address(this));
    rewardManager.withdrawUnclaimedRewards(eventId);
    uint256 balanceAfter = usdcToken.balanceOf(address(this));

    assertEq(balanceAfter - balanceBefore, rewardAmount);

    (,,, uint256 eventRewardAmount,, bool isCancelled, uint256 claimedAmount) =
      rewardManager.eventTokenRewards(eventId);

    assertEq(eventRewardAmount, 0, "Reward amount should be 0 after full withdrawal");
    assertTrue(isCancelled, "Event should be cancelled after full withdrawal");
    assertEq(claimedAmount, 0, "Claimed amount should remain 0");
  }

  // Function to test withdraw before the limited time
  function testWithdrawBeforeTimeout() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    vm.expectRevert("Withdrawal timeout not reached");
    rewardManager.withdrawUnclaimedRewards(eventId);
  }

  // Function to test partial withdraw unclaimed rewards
  function testWithdrawUnclaimedRewardsPartial() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    uint256 claimAmount = rewardAmount / 2;
    rewardManager.distributeTokenReward(eventId, participant, claimAmount);

    // Fast forward time
    vm.warp(block.timestamp + 31 days);

    uint256 initialBalance = usdcToken.balanceOf(address(this));

    rewardManager.withdrawUnclaimedRewards(eventId);

    uint256 finalBalance = usdcToken.balanceOf(address(this));

    assertEq(
      finalBalance - initialBalance, rewardAmount - claimAmount, "Incorrect withdrawal amount"
    );

    (,,, uint256 eventRewardAmount,, bool isCancelled, uint256 claimedAmount) =
      rewardManager.eventTokenRewards(eventId);

    assertEq(eventRewardAmount, claimAmount, "Reward amount should equal claimed amount");
    assertFalse(isCancelled, "Event should not be cancelled after partial withdrawal");
    assertEq(claimedAmount, claimAmount, "Claimed amount should remain unchanged");
  }

  // Function to test cancel and reclaim reward before the limited time
  function testCancelAndReclaimRewardBeforeTimeout() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    vm.expectRevert("Withdrawal timeout not reached");
    rewardManager.withdrawUnclaimedRewards(eventId);
  }

  // Function to test withdraw unclaim rewards for someone who isn't the event manager
  function testWithdrawUnclaimedRewardsNonManager() public {
    rewardManager.createTokenReward(
      eventId, EventRewardManager.TokenType.USDC, address(usdcToken), rewardAmount
    );

    // Fast forward time
    vm.warp(block.timestamp + 31 days);

    address nonManager = address(0x1234);
    vm.prank(nonManager);
    vm.expectRevert("Only event manager allowed");
    rewardManager.withdrawUnclaimedRewards(eventId);
  }
}
