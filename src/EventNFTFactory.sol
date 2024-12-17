// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;
import "./EventNFT.sol";

contract EventNFTFactory {
    EventNFT[] public eventNFTs;

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
    }

    function getEventNftClones() external returns (EventNFT[] memory) {
        return eventNFTs;
    }

    function getDeployedEventNftAddress(uint256 _index) external view returns (address) {
        require(_index < eventNFTs.length, "Index out of bounds");
        return eventNFTs[_index];
    }
}