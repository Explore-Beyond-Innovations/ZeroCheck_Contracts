// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IWorldID } from "./interfaces/IWorldID.sol";
import { IEventNFT } from "./interfaces/IEventNFT.sol";
import { ByteHasher } from "./helpers/ByteHasher.sol";

using ByteHasher for bytes;

contract EventNFT is ERC721, Ownable, IEventNFT {
  uint256 private _nextTokenId;
  string private _baseTokenURI;
  string public bonusURI;

  uint256 public maxSupply;

  address public eventManager;

  mapping(address => bool) public claimed; // Track if an address has already claimed an NFT
  mapping(address => bool) public bonusClaimed; // Track if an address has already claimed the Bonus
    // NFT
  mapping(uint256 => bool) public isBonusToken; //Mark the token ID as bonus token

  event AttemptingClaim(address participant, uint256 nextTokenId);
  event ClaimSuccessful(address participant, uint256 tokenId);

  constructor(
    string memory name,
    string memory symbol,
    uint256 _maxSupply,
    string memory baseURI,
    string memory _bonusURI, //Bonus for the first Registrant of an event
    address _eventManager
  )
    ERC721(name, symbol)
    Ownable(msg.sender)
  {
    _baseTokenURI = baseURI;
    maxSupply = _maxSupply;
    eventManager = _eventManager;
    bonusURI = _bonusURI;
  }

  modifier onlyeventManager() {
    require(msg.sender == eventManager, "EventNFT: Only event contract can mint");
    _;
  }

  function setEventManager(address _eventManager) external onlyOwner {
    require(_eventManager != address(0), "Invalid address");
    eventManager = _eventManager;
  }

  function claimNFT(address participant) external onlyeventManager returns (uint256) {
    require(_nextTokenId < maxSupply, "Max supply reached");
    emit AttemptingClaim(participant, _nextTokenId);

    require(!claimed[participant], "EventNFT: Nft Already Claimed");

    claimed[participant] = true;

    uint256 tokenId = _nextTokenId++;
    _safeMint(participant, tokenId);

    emit ClaimSuccessful(participant, tokenId);

    return tokenId;
  }

  function mintBonusNFT(address participant) external onlyeventManager returns (uint256) {
    require(!bonusClaimed[participant], "Bonus already claimed");

    uint256 tokenId = _nextTokenId++;
    isBonusToken[tokenId] = true;

    _safeMint(participant, tokenId);

    bonusClaimed[participant] = true;

    return tokenId;
  }

  function hasClaimedNFT(address user) external view returns (bool) {
    return claimed[user];
  }

  function hasClaimedBonusNFT(address user) external view returns (bool) {
    return bonusClaimed[user];
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_ownerOf(tokenId) != address(0), "Token does not exist");
    // Use bonusURI for bonus tokens
    if (isBonusToken[tokenId]) {
      return bonusURI;
    }

    // Use baseURI for regular tokens
    return _baseTokenURI;
  }

  function setBaseURI(string memory baseURI) external onlyOwner {
    _baseTokenURI = baseURI;
  }

  function setBonusURI(string memory newBonusURI) external onlyOwner {
    bonusURI = newBonusURI;
  }

  function supportsInterface(bytes4 interfaceId) public view override(ERC721) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
