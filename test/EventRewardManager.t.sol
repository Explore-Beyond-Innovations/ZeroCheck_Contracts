// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/EventManager.sol";
import "../src/EventNFT.sol";
import "../src/EventRewardManager.sol";

contract MockWorldID is IWorldID {
    uint256 private validRoot = 123_456_789; // Set a valid root for testing

    function setValidRoot(uint256 _root) external {
        validRoot = _root;
    }

    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof
    ) external view {
        require(root == validRoot, "Invalid root");
        require(nullifierHash != 0, "Invalid nullifierHash");
        // Proof validation skipped for simplicity in mock
    }
}

contract EventRewardManagerTest is Test {
    EventManager public eventManager;
    EventRewardManager public rewardManager;
    MockWorldID public mockWorldID;
    MockERC20 public usdcToken;
    MockERC20 public wldToken;
    EventNFT public eventNFT;

    uint256 public FIRST_PARTICIPANT_BONUS;

    address public owner;
    address public participant;
    address public unverifiedUser;
    address public user1;
    address public user2;
    address public user3;
    address public eventCreator;

    uint256 eventId;
    uint256 rewardAmount;

    function setUp() public {
        owner = address(this);
        participant = address(0x1337);
        user1 = address(0x15);
        user2 = address(0x210);
        user3 = address(0x315);
        eventCreator = address(0x348);

        // Deploy the mock contract and set the valid root
        mockWorldID = new MockWorldID();
        mockWorldID.setValidRoot(123_456_789); // Set the expected root value

        usdcToken = new MockERC20("USDC", "USDC", 6);
        wldToken = new MockERC20("WLD", "WLD", 18);

        eventManager = new EventManager(
            address(mockWorldID),
            123_456_789,
            "appId",
            "actionId",
            1
        );

        rewardManager = new EventRewardManager(address(eventManager));

        // Set the Reward Contract
        eventManager.setRewardContract(address(rewardManager));

        eventNFT = new EventNFT(
            "EventNFT",
            "ENFT",
            100,
            "https://base.uri/",
            "https://bonusbase.uri/",
            address(eventManager),
            owner,
            address(0x90)
        );

        // Mint and Approve Tokens
        uint256 _RewardAmount = 100 * 10 ** 6; // 100 USDC

        FIRST_PARTICIPANT_BONUS = 10 * 10 ** 6;

        // Mint USDC to eventCreator and approve EventManager and RewardManager
        usdcToken.mint(eventCreator, 1_000_000_000 * 1e6);

        // Act as eventCreator to approve tokens
        vm.startPrank(eventCreator);
        usdcToken.approve(address(eventManager), 1_000_000_000 * 1e6); // Approve EventManager
        usdcToken.approve(address(rewardManager), 1_000_000_000 * 1e6); // Approve RewardManager
        vm.stopPrank();

        // Mint tokens to EventManager (if it needs balance)
        usdcToken.mint(address(eventManager), _RewardAmount);
        vm.prank(address(eventManager));
        usdcToken.approve(address(rewardManager), _RewardAmount);

        // Create Event
        vm.prank(eventCreator);
        eventId = 0;
        eventManager.createEvent(
            "Devcon 2025",
            "Test Event",
            block.timestamp + 1 days,
            address(usdcToken),
            EventManager.RewardType.TOKEN,
            EventManager.TokenType.USDC,
            _RewardAmount
        );

        vm.prank(participant);
        eventManager.registerParticipant(
            eventId,
            12_344,
            [
                uint256(1),
                uint256(2),
                uint256(3),
                uint256(4),
                uint256(5),
                uint256(6),
                uint256(7),
                uint256(8)
            ]
        );

        vm.prank(user1);
        eventManager.registerParticipant(
            eventId,
            12_345,
            [
                uint256(1),
                uint256(2),
                uint256(3),
                uint256(4),
                uint256(5),
                uint256(6),
                uint256(7),
                uint256(8)
            ]
        );

        vm.prank(user2);
        eventManager.registerParticipant(
            eventId,
            12_346,
            [
                uint256(1),
                uint256(2),
                uint256(3),
                uint256(4),
                uint256(5),
                uint256(6),
                uint256(7),
                uint256(8)
            ]
        );

        vm.prank(user3);
        eventManager.registerParticipant(
            eventId,
            12_347,
            [
                uint256(1),
                uint256(2),
                uint256(3),
                uint256(4),
                uint256(5),
                uint256(6),
                uint256(7),
                uint256(8)
            ]
        );

        // Mint tokens to the test contract and approve the reward manager
        rewardAmount = 1000 * 10 ** 6; // 1000 USDC
        usdcToken.mint(address(this), rewardAmount);
        usdcToken.approve(address(rewardManager), rewardAmount);
    }

    function testCreateTokenReward() public {
        // Test event emitted as expected
        vm.expectEmit(true, true, true, true);
        emit EventRewardManager.TokenRewardCreated(
            eventId,
            address(eventCreator),
            address(usdcToken),
            EventRewardManager.TokenType.USDC,
            rewardAmount
        );

        // Create event token reward
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        // Verify created reward amount
        (
            address manager,
            address tokenAddress,
            EventRewardManager.TokenType tokenType,
            uint256 eventRewardAmount,
            uint256 createdAt,
            bool isCancelled,
            uint256 claimedAmount
        ) = rewardManager.eventTokenRewards(eventId);

        assert(manager == eventCreator);
        assert(tokenType == EventRewardManager.TokenType.USDC);
        assert(tokenAddress == address(usdcToken));
        assert(eventRewardAmount == rewardAmount);
        assert(createdAt > 0);
        assert(!isCancelled);
        assertEq(claimedAmount, 0);
    }

    function testCreateTokenRewardZeroAddress() public {
        // Attempt to create a token reward with a zero address
        vm.expectRevert("Zero token address detected");
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(0),
            rewardAmount,
            eventCreator
        );
    }

    function testCreateTokenRewardZeroAmount() public {
        // Attempt to create a token reward with a zero reward amount
        vm.expectRevert("Zero amount detected");
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            0,
            eventCreator
        );
    }

    function testCreateTokenRewardInvalidTokenType() public {
        // Attempt to create a token reward with an invalid token type
        vm.expectRevert("Invalid token type");
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.NFT,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
    }

    function testCreateTokenRewardEventDoesNotExist() public {
        uint256 invalidEventId = 420;

        // Attempt to create a token reward for a non-existent event
        vm.expectRevert("Event does not exist");
        rewardManager.createTokenReward(
            invalidEventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
    }

    function testUpdateTokenReward() public {
        uint256 additionalReward = 500 * 10 ** 6;

        // Create initial event token reward
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        // Mint more tokens to update event reward
        usdcToken.mint(address(this), additionalReward);
        usdcToken.approve(address(rewardManager), additionalReward);

        // Test event emitted as expected

        // vm.expectEmit(true, true, true, true);
        emit EventRewardManager.TokenRewardUpdated(
            eventId,
            address(this),
            additionalReward
        );
        rewardManager.updateTokenReward(
            address(eventCreator),
            eventId,
            additionalReward
        );

        // Verify the updated reward amount
        (
            address manager,
            address tokenAddress,
            EventRewardManager.TokenType tokenType,
            uint256 eventRewardAmount,
            uint256 createdAt,
            bool isCancelled,
            uint256 claimedAmount
        ) = rewardManager.eventTokenRewards(eventId);

        assert(manager == eventCreator);
        assert(tokenAddress == address(usdcToken));
        assert(tokenType == EventRewardManager.TokenType.USDC);
        assert(eventRewardAmount == rewardAmount + additionalReward);
    }

    function testUpdateTokenRewardOnlyEventManager() public {
        uint256 additionalReward = 500 * 10 ** 6;

        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            owner
        );

        // Attempt to update the token reward from a different address
        address nonManager = address(0x666);
        vm.prank(nonManager);
        vm.expectRevert("Only event manager allowed");
        rewardManager.updateTokenReward(
            eventCreator,
            eventId,
            additionalReward
        );
    }

    function testUpdateTokenRewardEventDoesNotExist() public {
        uint256 invalidEventId = 999;
        uint256 additionalReward = 500 * 10 ** 6;

        // Attempt to update the token reward for a non-existent event
        vm.expectRevert("Event does not exist");
        rewardManager.updateTokenReward(
            eventCreator,
            invalidEventId,
            additionalReward
        );
    }

    function testDistributeTokenReward() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            participant,
            rewardAmount
        );

        uint256 distributedReward = rewardManager.getUserTokenReward(
            eventId,
            participant
        );
        assertEq(distributedReward, rewardAmount);
    }

    function testRewardDistributedEvent() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        vm.expectEmit(true, true, false, true);
        emit EventRewardManager.TokenRewardDistributed(
            eventId,
            participant,
            rewardAmount
        );

        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            participant,
            rewardAmount
        );
    }

    function testDistributeTokenRewardEventDoesNotExist() public {
        uint256 invalidEventId = 1111;
        uint256 participantReward = 100 * 10 ** 6;

        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        // Attempt to distribute tokens for an event that does not exist
        vm.expectRevert("Event does not exist");
        rewardManager.distributeTokenReward(
            eventCreator,
            invalidEventId,
            participant,
            participantReward
        );
    }

    function testDistributeTokenRewardInsufficientRewardAmount() public {
        uint256 participantReward = 1100 * 10 ** 6;

        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        // Attempt to distribute more tokens than available in contract
        vm.expectRevert("Insufficient reward amount");
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            participant,
            participantReward
        );
    }

    function testGetUserTokenReward() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            participant,
            rewardAmount
        );

        assertEq(
            rewardManager.getUserTokenReward(eventId, participant),
            rewardAmount
        );
    }

    function testGetUserTokenRewardInvalidAddress() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        address zeroAddress = address(0);

        vm.prank(zeroAddress);
        vm.expectRevert("Zero Address Detected");

        rewardManager.getUserTokenReward(eventId, zeroAddress);
    }

    function testGetUserTokenRewardInvalidEventId() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        uint256 invalidEventId = 5;

        vm.prank(participant);
        vm.expectRevert("Event does not exist");

        rewardManager.getUserTokenReward(invalidEventId, participant);
    }

    function testClaimTokenReward() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            user1,
            rewardAmount
        );

        vm.prank(user1);
        rewardManager.claimTokenReward(eventId, user1);

        uint256 userBalance = usdcToken.balanceOf(user1);
        assertEq(userBalance, rewardAmount);

        uint256 remainingReward = rewardManager.getUserTokenReward(
            eventId,
            user1
        );
        assertEq(remainingReward, 0);
    }

    function testRewardClaimedEvent() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            user1,
            rewardAmount
        );

        vm.expectEmit(true, true, false, true);
        emit EventRewardManager.TokenRewardClaimed(
            eventId,
            user1,
            rewardAmount
        );

        vm.prank(user1);
        rewardManager.claimTokenReward(eventId, user1);
    }

    function testClaimTokenRewardInvalidParticipant() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            unverifiedUser,
            rewardAmount
        );

        vm.prank(unverifiedUser);
        vm.expectRevert("Not a registered participant");
        rewardManager.claimTokenReward(eventId, unverifiedUser);
    }

    function testFailDoubleClaimTokenReward() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            participant,
            rewardAmount
        );

        vm.startPrank(participant);
        rewardManager.claimTokenReward(eventId, participant);
        vm.expectRevert("Reward already claimed");
        rewardManager.claimTokenReward(eventId, participant);
        vm.stopPrank();
    }

    function testClaimTokenRewardInvalidEventId() public {
        vm.prank(participant);
        vm.expectRevert("Event does not exist");
        rewardManager.claimTokenReward(999, participant);
    }

    function testDistributeMultipleTokenRewards() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;

        uint256[] memory rewards = new uint256[](3);
        rewards[0] = 5;
        rewards[1] = 5;
        rewards[2] = 5;

        rewardManager.distributeMultipleTokenRewards(
            address(eventCreator),
            eventId,
            recipients,
            rewards
        );

        assertEq(
            rewardManager.getUserTokenReward(eventId, user1),
            5,
            "User1 reward incorrect"
        );
        assertEq(
            rewardManager.getUserTokenReward(eventId, user2),
            5,
            "User2 reward incorrect"
        );
        assertEq(
            rewardManager.getUserTokenReward(eventId, user3),
            5,
            "User3 reward incorrect"
        );

        (, , , uint256 remainingReward, , , ) = rewardManager.eventTokenRewards(
            eventId
        );
        assertEq(
            remainingReward,
            rewardAmount - 15,
            "Remaining reward incorrect"
        );
    }

    function testGetMultipleDistributedTokenRewards() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;

        uint256[] memory rewards = new uint256[](3);
        rewards[0] = 5;
        rewards[1] = 6;
        rewards[2] = 8;

        rewardManager.distributeMultipleTokenRewards(
            address(eventCreator),
            eventId,
            recipients,
            rewards
        );

        uint256[] memory distributedRewards = rewardManager
            .getMultipleDistributedTokenRewards(eventId, recipients);

        assertEq(
            distributedRewards.length,
            3,
            "Incorrect number of rewards returned"
        );
        assertEq(distributedRewards[0], 5, "User1 reward incorrect");
        assertEq(distributedRewards[1], 6, "User2 reward incorrect");
        assertEq(distributedRewards[2], 8, "User3 reward incorrect");
    }

    function testDistributeMultipleTokenRewardsInsufficientReward() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;

        uint256[] memory rewards = new uint256[](3);
        rewards[0] = 1_000_000_000;
        rewards[1] = 1_000_000_000;
        rewards[2] = 1_000_000_000;

        vm.expectRevert("Insufficient reward amount");
        rewardManager.distributeMultipleTokenRewards(
            address(eventCreator),
            eventId,
            recipients,
            rewards
        );
    }

    function testDistributeMultipleTokenRewardsArrayMismatch() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        address[] memory recipients = new address[](3);
        recipients[0] = user1;
        recipients[1] = user2;
        recipients[2] = user3;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = 5;
        rewards[1] = 5;

        vm.expectRevert("Arrays length mismatch");
        rewardManager.distributeMultipleTokenRewards(
            address(eventCreator),
            eventId,
            recipients,
            rewards
        );
    }

    function testDistributedMultipleTokenRewardsEmptyArray() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );

        address[] memory emptyRecipients = new address[](0);
        uint256[] memory emptyRewards = new uint256[](0);

        vm.expectRevert("Empty arrays");
        rewardManager.distributeMultipleTokenRewards(
            address(eventCreator),
            eventId,
            emptyRecipients,
            emptyRewards
        );
    }

    function testGetMultipleDistributedTokenRewardsEmptyArray() public view {
        address[] memory emptyRecipients = new address[](0);
        uint256[] memory emptyRewards = rewardManager
            .getMultipleDistributedTokenRewards(eventId, emptyRecipients);

        assertEq(
            emptyRewards.length,
            0,
            "Empty array should be returned for empty input"
        );
    }

    function testSetFirstParticipantBonus() public {
        rewardManager.createTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount,
            eventCreator
        );
        rewardManager.distributeTokenReward(
            eventCreator,
            eventId,
            participant,
            rewardAmount
        );

        // Mint more tokens to update event reward
        usdcToken.mint(address(this), FIRST_PARTICIPANT_BONUS);
        usdcToken.approve(address(rewardManager), FIRST_PARTICIPANT_BONUS);

        // Test event emitted as expected

        // vm.expectEmit(true, true, true, true);
        emit EventRewardManager.TokenRewardUpdated(
            eventId,
            address(this),
            FIRST_PARTICIPANT_BONUS
        );
        rewardManager.updateTokenReward(
            address(eventCreator),
            eventId,
            FIRST_PARTICIPANT_BONUS
        );

        rewardManager.setFirstParticipantTokenBonus(
            eventId,
            participant,
            eventCreator,
            FIRST_PARTICIPANT_BONUS
        );

        usdcToken.mint(eventCreator, FIRST_PARTICIPANT_BONUS);

        uint256 distributedReward = rewardManager.getUserTokenReward(
            eventId,
            participant
        );
        assertEq(distributedReward, rewardAmount + FIRST_PARTICIPANT_BONUS);
    }
}

// Mock ERC20 Token for Testing
contract MockERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public returns (bool) {
        require(balanceOf[sender] >= amount, "Insufficient balance");
        require(
            allowance[sender][msg.sender] >= amount,
            "Insufficient allowance"
        );

        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        allowance[sender][msg.sender] -= amount;

        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }
}
