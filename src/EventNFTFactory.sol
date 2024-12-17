// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import "./EventNFT.sol";

/// @title EventNFTFactory
/// @notice This contract is used to create and manage multiple EventNFT contracts
contract EventNFTFactory {
    // Array to store all created EventNFT contracts
    EventNFT[] public eventNFTs;

    // Event emitted when a new EventNFT contract is created    
    event EventNFTCreated(address indexed eventNFTAddress, address indexed owner);

    /// @notice createEventNFT function creates a new EventNFT contract
    /// @param _name The name of the EventNFT
    /// @param _symbol The symbol of the EventNFT
    /// @param _maxSupply The maximum supply of the EventNFT
    /// @param _baseURI The base URI for token metadata
    /// @param _eventContract The address of the associated event contract
    /// @return newEventNFT_ The address of the newly created EventNFT contract
    /// @return length_ The current number of EventNFT contracts created
    function createEventNFT(string memory _name, string memory _symbol, uint256 _maxSupply, string memory _baseURI, address _eventContract) external returns (EventNFT newEventNFT_, uint256 length_) {
        // Create a new EventNFT contract
        newEventNFT_ = new EventNFT(
            _name,
            _symbol,
            _maxSupply,
            _baseURI,
            _eventContract,
            msg.sender
        );

        // Add the new EventNFT to the array
        eventNFTs.push(newEventNFT_);

        // Get the current number of EventNFTs
        length_ = eventNFTs.length;

        // Emit an event for the new EventNFT creation
        emit EventNFTCreated(address(newEventNFT_), msg.sender);
    }

    /// @notice Retrieves all created EventNFT contracts
    /// @return An array of all EventNFT contracts
    function getEventNFTClones() external view returns (EventNFT[] memory) {
        return eventNFTs;
    }
}