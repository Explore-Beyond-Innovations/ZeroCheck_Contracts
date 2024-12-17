// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import "./EventNFT.sol";

contract EventNFTFactory {
    EventNFT[] public eventNFTs;

    event EventNFTCreated(address indexed eventNFTAddress, address indexed owner);

    function createEventNFT(string memory _name, string memory _symbol, uint256 _maxSupply, string memory _baseURI, address _eventContract) external returns (EventNFT newEventNFT_, uint256 length_) {
        newEventNFT_ = new EventNFT(
            _name,
            _symbol,
            _maxSupply,
            _baseURI,
            _eventContract,
            msg.sender
        );

        eventNFTs.push(newEventNFT_);

        length_ = eventNFTs.length;

        emit EventNFTCreated(address(newEventNFT_), msg.sender);
    }

    function getEventNFTClones() external view returns (EventNFT[] memory) {
        return eventNFTs;
    }
}