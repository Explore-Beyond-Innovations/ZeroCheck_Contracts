// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract EventNFT is ERC721, Ownable {
  uint256 private _nextTokenId;
  string private _baseTokenURI;
  uint256 public maxSupply;

  address public eventContract;

  bytes32 public merkleRoot; // Merkle root of the participant list
  mapping(address => bool) public claimed; // Track if an address has already claimed an NFT

  constructor(
    string memory name,
    string memory symbol,
    uint256 _maxSupply,
    string memory baseURI,
    address _eventContract,
    address owner
  )
    ERC721(name, symbol)
    Ownable(owner)
  {
    _baseTokenURI = baseURI;
    maxSupply = _maxSupply;
    eventContract = _eventContract;
  }

  modifier onlyEventContract() {
    require(msg.sender == eventContract, "EventNFT: Only event contract can mint");
    _;
  }

  modifier onlyEligibleParticipant(address participant, bytes32[] calldata proof) {
    require(
      MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(participant))),
      "EventNFT: You are not an eligible participant"
    );
    require(!claimed[participant], "EventNFT: You have already claimed your NFT");
    _;
  }

  function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function setEventContract(address _eventContract) external onlyOwner {
    require(_eventContract != address(0), "Invalid address");
    eventContract = _eventContract;
  }

  function claimNFT(
    address participant,
    bytes32[] calldata proof
  )
    external
    onlyEventContract
    onlyEligibleParticipant(participant, proof)
  {
    require(_nextTokenId < maxSupply, "Max supply reached");

    claimed[participant] = true;

    uint256 tokenId = _nextTokenId++;
    _safeMint(participant, tokenId);
  }

  function setBaseURI(string memory baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
