// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IWorldID} from "./interfaces/IWorldID.sol";
import {ByteHasher} from "./helpers/ByteHasher.sol";

using ByteHasher for bytes;

contract EventNFT is ERC721, Ownable {
    uint256 private _nextTokenId;
    string private _baseTokenURI;
    uint256 public maxSupply;

    address public eventContract;
    address public worldIDAddr;

    IWorldID internal immutable worldId;

    bytes32 public merkleRoot; // Merkle root of the participant list
    mapping(address => bool) public claimed; // Track if an address has already claimed an NFT

    event AttemptingClaim(address participant, uint256 nextTokenId);
    event ClaimSuccessful(address participant, uint256 tokenId);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _maxSupply,
        string memory baseURI,
        address _eventContract,
        address owner,
        address _worldIdAddress
    ) ERC721(name, symbol) Ownable(owner) {
        _baseTokenURI = baseURI;
        maxSupply = _maxSupply;
        eventContract = _eventContract;
        worldIDAddr = _worldIdAddress;
        worldId = IWorldID(_worldIdAddress);
    }

    modifier onlyEventContract() {
        require(
            msg.sender == eventContract,
            "EventNFT: Only event contract can mint"
        );
        _;
    }

    modifier isValidParticipant(
        uint256 worldIdRoot,
        uint256 groupId,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof,
        address participant
    ) {
        try
            worldId.verifyProof(
                worldIdRoot,
                groupId,
                abi.encodePacked(participant).hashToField(),
                nullifierHash,
                externalNullifier,
                proof
            )
        {
            _;
        } catch {
            revert("EventNFT: Invalid Proof");
        }
    }

    function setEventContract(address _eventContract) external onlyOwner {
        require(_eventContract != address(0), "Invalid address");
        eventContract = _eventContract;
    }

    function claimNFTWithZk(
        uint256 worldIdRoot,
        uint256 groupId,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof,
        address participant
    )
        external
        onlyEventContract
        isValidParticipant(
            worldIdRoot,
            groupId,
            nullifierHash,
            externalNullifier,
            proof,
            participant
        )
        returns (bool, address, uint256)
    {
        require(_nextTokenId < maxSupply, "Max supply reached");
        emit AttemptingClaim(participant, _nextTokenId);

        claimed[participant] = true;

        uint256 tokenId = _nextTokenId++;
        _safeMint(participant, tokenId);

        emit ClaimSuccessful(participant, tokenId);

        return (true, participant, tokenId);
    }

    function hasClaimedNFT(address user) external view returns (bool) {
        return claimed[user];
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
