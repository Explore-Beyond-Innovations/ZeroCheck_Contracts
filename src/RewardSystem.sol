// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.22;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./EventNFTFactory.sol";


contract RewardSystem is Ownable {
     // Reference to the EventNFTFactory
    EventNFTFactory public immutable nftFactory;
    
    // Reward types
    enum RewardType { NFT, TOKEN }
    
    struct Reward {
        RewardType rewardType;
        address tokenAddress;      // For ERC20 rewards
        uint256 tokenAmount;       // For ERC20 rewards
        address nftAddress;        // Address of the EventNFT contract
        uint256 nftTokenId;        // Token ID for the NFT
        bool claimed;
    }
    
    // Counter for reward IDs
    uint256 private _currentRewardId;
    
    // Mapping from reward ID to Reward struct
    mapping(uint256 => Reward) public rewards;
    
    // Mapping to track user rewards
    mapping(address => uint256[]) public userRewards;
    
    // Events
    event RewardCreated(uint256 indexed rewardId, RewardType rewardType);
    event RewardClaimed(address indexed user, uint256 indexed rewardId);
    event NFTRewardCreated(
        uint256 indexed rewardId, 
        address indexed nftContract, 
        uint256 tokenId
    );
    
    constructor(address _nftFactory) {
        nftFactory = EventNFTFactory(_nftFactory);
    }
    
    function createNFTReward(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _baseURI,
        address _eventContract
    ) external onlyOwner returns (uint256) {
        // Create new EventNFT contract using factory
        (EventNFT newEventNFT, ) = nftFactory.createEventNFT(
            _name,
            _symbol,
            _maxSupply,
            _baseURI,
            _eventContract
        );
        
        // Increment reward ID
        _currentRewardId++;
        uint256 newRewardId = _currentRewardId;
        
        // Create new reward
        rewards[newRewardId] = Reward({
            rewardType: RewardType.NFT,
            tokenAddress: address(0),
            tokenAmount: 0,
            nftAddress: address(newEventNFT),
            nftTokenId: 1, // First token ID
            claimed: false
        });
        
        emit RewardCreated(newRewardId, RewardType.NFT);
        emit NFTRewardCreated(newRewardId, address(newEventNFT), 1);
        
        return newRewardId;
    }
    
    function createTokenReward(
        address _tokenAddress,
        uint256 _tokenAmount
    ) external onlyOwner returns (uint256) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_tokenAmount > 0, "Invalid token amount");
        
        // Increment reward ID
        _currentRewardId++;
        uint256 newRewardId = _currentRewardId;
        
        // Create new reward
        rewards[newRewardId] = Reward({
            rewardType: RewardType.TOKEN,
            tokenAddress: _tokenAddress,
            tokenAmount: _tokenAmount,
            nftAddress: address(0),
            nftTokenId: 0,
            claimed: false
        });
        
        emit RewardCreated(newRewardId, RewardType.TOKEN);
        
        return newRewardId;
    }
    
    function claimReward(uint256 _rewardId) external {
        require(_rewardId <= _currentRewardId, "Invalid reward ID");
        require(!rewards[_rewardId].claimed, "Reward already claimed");
        
        Reward storage reward = rewards[_rewardId];
        reward.claimed = true;
        
        if (reward.rewardType == RewardType.NFT) {
            // Get the EventNFT contract
            EventNFT nftContract = EventNFT(reward.nftAddress);
            
            // Mint NFT to the claimer
            nftContract.mint(msg.sender);
            
            // Update the next token ID for future mints
            reward.nftTokenId++;
            
        } else {
            // Transfer tokens
            require(
                IERC20(reward.tokenAddress).transfer(msg.sender, reward.tokenAmount),
                "Token transfer failed"
            );
        }
        
        userRewards[msg.sender].push(_rewardId);
        emit RewardClaimed(msg.sender, _rewardId);
    }
    
    // View functions
    function getUserRewards(address _user) external view returns (uint256[] memory) {
        return userRewards[_user];
    }
    
    function isRewardClaimed(uint256 _rewardId) external view returns (bool) {
        return rewards[_rewardId].claimed;
    }
    
    function getRewardDetails(uint256 _rewardId) 
        external 
        view 
        returns (
            RewardType rewardType,
            address tokenAddress,
            uint256 tokenAmount,
            address nftAddress,
            uint256 nftTokenId,
            bool claimed
        ) 
    {
        Reward memory reward = rewards[_rewardId];
        return (
            reward.rewardType,
            reward.tokenAddress,
            reward.tokenAmount,
            reward.nftAddress,
            reward.nftTokenId,
            reward.claimed
        );
    }
    
   
} 