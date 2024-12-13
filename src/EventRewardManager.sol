// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import "../src/EventManager.sol";

contract EventRewardManager is Ownable(msg.sender) {
    EventManager public eventManager;

    enum TokenType {
        NONE,
        USDC,
        WLD
    }

    struct TokenReward {
        TokenType tokenType;
        address tokenAddress;
        uint256 rewardAmount;
        uint256 totalRewardPool;
    }

    mapping(uint256 => TokenReward) public eventTokenRewards;

    event TokenRewardCreated(
        uint256 indexed eventId,
        TokenType tokenType,
        address tokenAddress,
        uint256 indexed rewardAmount
    );

    function checkZeroAddress() internal view {
        if (msg.sender == address(0)) revert("Zero address detected!");
    }

    function checkEventIsValid(uint256 _eventId) internal view {
        if (eventManager.getEvent(_eventId).id == 0)
            revert("Event does not exist");
    }

    // Set up token-based event rewards
    function setupTokenReward(
        uint256 _eventId,
        TokenType _tokenType,
        address _tokenAddress,
        uint256 _rewardAmount
    ) external onlyOwner {
        checkZeroAddress();

        if (_tokenAddress == address(0)) revert("Zero token address detected");

        if (_rewardAmount == 0) revert("Zero amount detected");

        if (_tokenType != TokenType.USDC && _tokenType != TokenType.WLD)
            revert("Invalid token type");

        // checkEventIsValid(_eventId);

        eventTokenRewards[_eventId] = TokenReward({
            tokenType: _tokenType,
            tokenAddress: _tokenAddress,
            rewardAmount: _rewardAmount,
            totalRewardPool: 0
        });

        emit TokenRewardCreated(
            _eventId,
            _tokenType,
            _tokenAddress,
            _rewardAmount
        );
    }

    // Transfer tokens into the contract for an event
    function transferTokenReward(uint256 _eventId, uint256 _amount) external {
        checkZeroAddress();

        // checkEventIsValid(_eventId);

        TokenReward storage eventReward = eventTokenRewards[_eventId];

        if (eventReward.rewardAmount == 0) revert("Event reward non-existent");

        if (
            eventReward.tokenType != TokenType.USDC &&
            eventReward.tokenType == TokenType.WLD
        ) {
            revert("No event token reward");
        }

        // if (eventReward.rewardAmount != _amount)
        //     revert("Incorrect reward amount sent");

        eventReward.totalRewardPool += _amount;

        // Transfer tokens from event manager to contract
        IERC20 token = IERC20(eventReward.tokenAddress);
        require(
            token.transferFrom(msg.sender, address(this), _amount),
            "Token transfer failed"
        );
    }

    // Function to distribute tokens to event participants
    function distributeTokenReward(
        uint256 _eventId,
        address _recipient,
        uint256 _participantReward
    ) external onlyOwner {
        // checkEventIsValid(_eventId);

        TokenReward storage eventReward = eventTokenRewards[_eventId];

        if (
            eventReward.tokenType != TokenType.USDC &&
            eventReward.tokenType == TokenType.WLD
        ) {
            revert("No event token reward");
        }

        if (eventReward.totalRewardPool < _participantReward)
            revert("Insufficient reward pool");

        eventReward.totalRewardPool -= _participantReward;

        // Transfer tokens to participant
        IERC20 token = IERC20(eventReward.tokenAddress);
        require(
            token.transfer(_recipient, _participantReward),
            "Token distribution failed"
        );
    }
}
