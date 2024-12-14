// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract EventManager {
  ////////////////////////////////////////////////////////////////
  ///                      CONFIG STORAGE                      ///
  ////////////////////////////////////////////////////////////////
  /// @dev The address of the World ID Router contract that will be used for verifying proofs
  IWorldID internal immutable worldId;
  // address public worldID;

  address public rewardContract;
  string public appId;
  string public actionId;

  ////////////////////////////////////////////////////////////////
  ///                       CONSTRUCTOR                        ///
  ////////////////////////////////////////////////////////////////

  /// @param _worldId The address of the WorldIDRouter that will verify the proofs
  /// @param _appId The World ID App ID (from Developer Portal)
  /// @param _actionId The World ID Action (from Developer Portal)
  constructor(
    address _worldID,
    address _rewardContract,
    string memory _appId,
    string memory _actionId
  ) {
    worldID = _worldID;
    rewardContract = _rewardContract;
    appId = _appId;
    actionId = _actionId;
  }

  struct Event {
    uint256 id;
    address creator;
    string description;
  }

  Event[] public events;

  ////////////////////////////////////////////////////////////////
  ///                        FUNCTIONS                         ///
  ////////////////////////////////////////////////////////////////

  //fetch event by ID
  function getEvent(uint256 id) public view returns (Event memory) {
    if (id >= events.length) revert("Event does not exist");
    return events[id];
  }

  // Fetch all events
  function getAllEvents() public view returns (Event[] memory) {
    return events;
  }

  // Function to add events for testing purposes
  function addEventForTesting(uint256 id, string memory description, address creator) public {
    events.push(Event({ id: id, description: description, creator: creator }));
  }
}
