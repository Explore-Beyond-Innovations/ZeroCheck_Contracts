// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/RewardSystem.sol";
import "../src/EventNFTFactory.sol";
import "../src/EventNFT.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MTK") {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

contract RewardSystemTest is Test {
    RewardSystem public rewardSystem;
    EventNFTFactory public nftFactory;
    MockERC20 public mockToken;
    
    address public owner;
    address public user1;
    address public user2;
    
    event RewardCreated(uint256 indexed rewardId, RewardSystem.RewardType rewardType);
    event RewardClaimed(address indexed user, uint256 indexed rewardId);
    event NFTRewardCreated(uint256 indexed rewardId, address indexed nftContract, uint256 tokenId);
    
    function setUp() public {
        // Setup accounts
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        // Deploy contracts
        nftFactory = new EventNFTFactory();
        rewardSystem = new RewardSystem(address(nftFactory));
        mockToken = new MockERC20();
        
        // Fund test accounts
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        mockToken.transfer(address(rewardSystem), 10000 * 10**18);
    }

    function testCreateNFTReward() public {
        // Expect events to be emitted
        vm.expectEmit(true, true, true, true);
        emit RewardCreated(1, RewardSystem.RewardType.NFT);
        
        // Create NFT reward
        uint256 rewardId = rewardSystem.createNFTReward(
            "Test NFT",
            "TNFT",
            100,
            "baseURI/",
            address(this)
        );
        
        // Verify reward details
        (
            RewardSystem.RewardType rewardType,
            address tokenAddress,
            uint256 tokenAmount,
            address nftAddress,
            uint256 nftTokenId,
            bool claimed
        ) = rewardSystem.getRewardDetails(rewardId);
        
        assertEq(uint256(rewardType), uint256(RewardSystem.RewardType.NFT));
        assertEq(tokenAddress, address(0));
        assertEq(tokenAmount, 0);
        assertTrue(nftAddress != address(0));
        assertEq(nftTokenId, 1);
        assertFalse(claimed);
    }
    
    function testCreateTokenReward() public {
        uint256 rewardAmount = 100 * 10**18;
        
        // Expect event to be emitted
        vm.expectEmit(true, true, true, true);
        emit RewardCreated(1, RewardSystem.RewardType.TOKEN);
        
        // Create token reward
        uint256 rewardId = rewardSystem.createTokenReward(
            address(mockToken),
            rewardAmount
        );
        
        // Verify reward details
        (
            RewardSystem.RewardType rewardType,
            address tokenAddress,
            uint256 tokenAmount,
            address nftAddress,
            uint256 nftTokenId,
            bool claimed
        ) = rewardSystem.getRewardDetails(rewardId);
        
        assertEq(uint256(rewardType), uint256(RewardSystem.RewardType.TOKEN));
        assertEq(tokenAddress, address(mockToken));
        assertEq(tokenAmount, rewardAmount);
        assertEq(nftAddress, address(0));
        assertEq(nftTokenId, 0);
        assertFalse(claimed);
    }
    
    function testClaimNFTReward() public {
        // Create NFT reward
        uint256 rewardId = rewardSystem.createNFTReward(
            "Test NFT",
            "TNFT",
            100,
            "baseURI/",
            address(this)
        );
        
        // Switch to user1 and claim reward
        vm.startPrank(user1);
        
        // Expect event to be emitted
        vm.expectEmit(true, true, true, true);
        emit RewardClaimed(user1, rewardId);
        
        rewardSystem.claimReward(rewardId);
        
        // Verify reward is claimed
        assertTrue(rewardSystem.isRewardClaimed(rewardId));
        
        // Verify user1 owns the NFT
        (,,,address nftAddress,,) = rewardSystem.getRewardDetails(rewardId);
        EventNFT nft = EventNFT(nftAddress);
        assertEq(nft.ownerOf(1), user1);
        
        vm.stopPrank();
    }
}