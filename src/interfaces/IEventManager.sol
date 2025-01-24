// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { IWorldID } from "../interfaces/IWorldID.sol";
import { IEventRewardManager } from "../interfaces/IEventRewardManager.sol";
import "../EventManager.sol";

interface IEventManager {
  function setRewardManager(address _rewardManagerAddress) external;

  function createEvent(string memory name, string memory description, uint256 timestamp) external;

  function closeEvent(uint256 _eventId) external;

  function registerParticipant(
    uint256 eventId,
    uint256 nullifierHash,
    uint256[8] calldata proof
  )
    external;

  function createReward(
    uint256 _eventId,
    string memory _tokenName,
    string memory _tokenSymbol,
    uint256 _maxSupply,
    string memory _baseURI,
    IEventRewardManager.TokenType _tokenType,
    address _tokenAddress,
    uint256 _rewardAmount,
    string memory _BonusbaseURI
  )
    external;

  function updateEventTokenReward(uint256 _eventId, uint256 _amount) external;

  function setTokenRewardForParticipant(
    uint256 eventId,
    address _participant,
    uint256 _reward
  )
    external;

  function setBulkRewardsForParticipants(
    uint256 eventId,
    address[] calldata _participants,
    uint256[] calldata _rewards
  )
    external;

  function claimReward(uint256 eventId, uint256 nullifierHash, uint256[8] calldata proof) external;

  function claimNFTReward(
    uint256 eventId,
    uint256 nullifierHash,
    uint256[8] calldata proof
  )
    external;
}
