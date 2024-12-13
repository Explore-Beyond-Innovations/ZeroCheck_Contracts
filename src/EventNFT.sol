// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EventNFT is ERC721, Ownable {
    uint256 private _nextTokenId;
    string private _baseTokenURI;
    uint256 public maxSupply;

    address public eventContract;
    mapping(address => bool) public participants; // Track eligible participants
    mapping(address => bool) public claimed; // Track if an address has already claimed an NFT

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        string memory baseURI,
        address owner
    ) ERC721(name, symbol) Ownable(owner) {
        _baseTokenURI = baseURI;
        maxSupply = _maxSupply;
    }

    modifier onlyEventContract() {
        require(
            msg.sender == eventContract,
            "EventNFT: Only event contract can mint"
        );
        _;
    }

    modifier onlyEligibleParticipant(address participant) {
        require(
            participants[participant],
            "EventNFT: You are not an eligible participant"
        );
        require(
            !claimed[participant],
            "EventNFT: You have already claimed your NFT"
        );
        _;
    }

    function setEventContract(address _eventContract) external onlyOwner {
        require(_eventContract != address(0), "Invalid address");
        eventContract = _eventContract;
    }

    function addParticipant(address participant) external onlyEventContract {
        require(participant != address(0), "Invalid address");
        participants[participant] = true;
    }

    function removeParticipant(address participant) external onlyEventContract {
        require(participant != address(0), "Invalid address");
        participants[participant] = false;
    }

    function claimNFT(
        address participant
    ) external onlyEventContract onlyEligibleParticipant(participant) {
        require(_nextTokenId < maxSupply, "Max supply reached");

        claimed[participant] = true;

        uint256 tokenId = _nextTokenId++;
        _safeMint(participant, tokenId);
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
