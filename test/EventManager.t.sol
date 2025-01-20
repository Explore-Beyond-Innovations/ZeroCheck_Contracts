// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/EventManager.sol";
import "../src/EventNFT.sol";
import "../src/EventRewardManager.sol";
import "../src/interfaces/IWorldID.sol";
import "../src/EventNFTFactory.sol";
import "../src/EventRewardManager.sol";

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

contract MockWorldID is IWorldID {
    bool private isValid;
    mapping(uint256 => bool) public nullifierHashes;

    error InvalidNullifier();

    constructor() {
        isValid = true;
    }

    function setValid(bool _isValid) external {
        isValid = _isValid;
    }

    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof
    ) external view override {
        // Check if mock is set to valid state
        require(isValid, "Mock WorldID: Invalid proof");

        // Basic nullifier check
        if (nullifierHashes[nullifierHash]) {
            revert InvalidNullifier();
        }

        // In a mock, we don't actually verify the ZK proof
        // Just ensure the parameters are not zero to simulate basic validation
        require(root != 0, "Mock WorldID: Invalid root");
        require(groupId != 0, "Mock WorldID: Invalid group ID");
        require(signal != 0, "Mock WorldID: Invalid signal");
        require(nullifierHash != 0, "Mock WorldID: Invalid nullifier hash");
        require(
            externalNullifier != 0,
            "Mock WorldID: Invalid external nullifier"
        );

        // We don't check the actual proof values in the mock
        // but we ensure the array is the correct length
        require(proof.length == 8, "Mock WorldID: Invalid proof length");
    }

    // Helper function to simulate nullifier registration
    function registerNullifier(uint256 nullifierHash) external {
        nullifierHashes[nullifierHash] = true;
    }

    // Helper function to check if a nullifier has been used
    function isNullifierUsed(
        uint256 nullifierHash
    ) external view returns (bool) {
        return nullifierHashes[nullifierHash];
    }
}

contract EventManagerTest is Test {
 main
  EventManager private eventManager;
    EventNFTFactory private nftFactory;
    EventRewardManager private rewardManager;

  event ParticipantRegistered(uint256 eventId, address indexed participant);

  address constant REWARD_CONTRACT = address(0x5678);
  address constant WORLD_ID_CONTRACT = address(0x1234);
  uint256 constant WORLD_ID_ROOT = 123_456_789;

  event EventRegistered(uint256 id, string description, address indexed creator);
  event RewardCreated(
        uint256 indexed eventId,
        address indexed nftAddress,
        address tokenAddress,
        EventRewardManager.TokenType rewardType,
        uint256 rewardAmount
    );

  function setUp() public {
    eventManager =
      new EventManager(WORLD_ID_CONTRACT, WORLD_ID_ROOT, REWARD_CONTRACT, "appId", "actionId");
  }
        nftFactory = new EventNFTFactory();
        rewardManager = new EventRewardManager(address(this));

  function testEventManagerConstruction() public view {
    assertEq(address(eventManager.getWorldId()), address(WORLD_ID_CONTRACT));
    assertEq(eventManager.rewardContract(), REWARD_CONTRACT);
    assertEq(eventManager.appId(), "appId");
    assertEq(eventManager.actionId(), "actionId");
  }

  function testGetEvent() public {
    // Use the createEvent function to add an event
    eventManager.createEvent("Event Name", "Test Event", block.timestamp + 1 days, "Gold");

    EventManager.Event memory evt = eventManager.getEvent(0);
    assertEq(evt.description, "Test Event");
    assertEq(evt.creator, address(this));
    assertEq(evt.id, 0);
    assertEq(evt.name, "Event Name");
    assertEq(evt.timestamp, block.timestamp + 1 days);
    assertEq(evt.rewardType, "Gold");
  }

  function testGetAllEvents() public {
    // Use the createEvent function to add events
    eventManager.createEvent("Event One", "First Event", block.timestamp + 1 days, "Gold");
    eventManager.createEvent("Event Two", "Second Event", block.timestamp + 2 days, "Silver");

    EventManager.Event[] memory events = eventManager.getAllEvents();
    assertEq(events.length, 2);
    assertEq(events[0].description, "First Event");
    assertEq(events[1].description, "Second Event");
    assertEq(events[0].name, "Event One");
    assertEq(events[1].rewardType, "Silver");
  }

  // Unit Test for Create Events
  function testCreateEventSuccess() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory eventDescription = "This is a test event";
    uint256 eventTimestamp = block.timestamp + 1 days;
    string memory eventRewardType = "Token";

    // Act
    eventManager.createEvent(eventName, eventDescription, eventTimestamp, eventRewardType);

    // Assert
    EventManager.Event memory evt = eventManager.getEvent(0);
    assertEq(evt.id, 0);
    assertEq(evt.creator, address(this));
    assertEq(evt.description, eventDescription);
    assertEq(evt.name, eventName);
    assertEq(evt.timestamp, eventTimestamp);
    assertEq(evt.rewardType, eventRewardType);
  }

  function testCreateEventFailsWhenNameIsEmpty() public {
    // Arrange
    string memory emptyName = "";
    string memory eventDescription = "This is a test event";
    uint256 eventTimestamp = block.timestamp + 1 days;
    string memory eventRewardType = "Token";

    // Act & Assert
    vm.expectRevert(bytes("Event name is required"));
    eventManager.createEvent(emptyName, eventDescription, eventTimestamp, eventRewardType);
  }

  function testCreateEventFailsWhenDescriptionIsEmpty() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory emptyDescription = "";
    uint256 eventTimestamp = block.timestamp + 1 days;
    string memory eventRewardType = "Token";

    // Act & Assert
    vm.expectRevert(bytes("Description is required"));
    eventManager.createEvent(eventName, emptyDescription, eventTimestamp, eventRewardType);
  }

  function testCreateEventFailsWhenTimestampIsNotFuture() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory eventDescription = "This is a test event";
    uint256 currentTime = block.timestamp;
    uint256 pastTimestamp = currentTime - 1;
    string memory eventRewardType = "Token";

    // Act
    vm.expectRevert(bytes("Timestamp must be in the future"));

    // Assert
    eventManager.createEvent(eventName, eventDescription, pastTimestamp, eventRewardType);
  }

  function testCreateEventFailsWhenRewardTypeIsEmpty() public {
    // Arrange
    string memory eventName = "Test Event";
    string memory eventDescription = "This is a test event";
    uint256 eventTimestamp = block.timestamp + 1 days;
    string memory emptyRewardType = "";

    // Act & Assert
    vm.expectRevert(bytes("Reward type is required"));
    eventManager.createEvent(eventName, eventDescription, eventTimestamp, emptyRewardType);
  }

  function testRegisterParticipantSuccess() public {
    // Arrange
    uint256 nullifierHash = 12_345;
    uint256[8] memory proof = [
      uint256(1),
      uint256(2),
      uint256(3),
      uint256(4),
      uint256(5),
      uint256(6),
      uint256(7),
      uint256(8)
    ];

    // Mock call for World ID proof verification
    vm.mockCall(
      WORLD_ID_CONTRACT,
      abi.encodeWithSignature(
        "verifyProof(uint256,uint256,uint256[8])", WORLD_ID_ROOT, nullifierHash, proof
      ),
      abi.encode(true)
=======
    EventManager public eventManager;
    MockWorldID public mockWorldId;
    EventNFT public mockEventNFT;
    EventRewardManager public mockRewardManager;
    MockERC20 public mockUSDC;
    MockERC20 public mockWLD;

    address public owner;
    address public eventCreator;
    address public user1;
    address public user2;

    // Test data
    uint256 constant ROOT = 1234;
    string constant APP_ID = "app_test";
    string constant ACTION_ID = "action_test";
    uint256 constant GROUP_ID = 1;

    // Event data
    string constant EVENT_NAME = "Test Event";
    string constant EVENT_DESCRIPTION = "Test Description";
    uint256 constant FUTURE_TIMESTAMP = 1_735_689_600; // Jan 1, 2025
    uint256 constant REWARD_AMOUNT = 100;
    uint256 constant BONUSTOKEN = 10;

    event BulkTokenRewardSet(
        uint256 indexed eventId,
        address[] indexed recipients,
        uint256[] amounts
main
    );

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        eventCreator = address(0x3);

        // Deploy mock contracts
        mockWorldId = new MockWorldID();

        mockUSDC = new MockERC20("USDC", "USDC", 6);
        mockWLD = new MockERC20("WLD", "WLD", 18);

        // Deploy EventManager
        eventManager = new EventManager(
            address(mockWorldId),
            ROOT,
            APP_ID,
            ACTION_ID,
            GROUP_ID
        );

        mockRewardManager = new EventRewardManager(address(eventManager));

        mockEventNFT = new EventNFT(
            "EventNFT",
            "ENFT",
            100,
            "https://base.uri/",
            "https://bonusbase.uri/",
            address(eventManager),
            owner,
            address(mockWorldId)
        );

        // Set reward contract
        eventManager.setRewardContract(address(mockRewardManager));

        //Mint Tokens to Event Creator
        mockUSDC.mint(address(eventCreator), 10_000 * 10 ** 6);
        //Approve eventManager to spend
        vm.startPrank(eventCreator);
        mockUSDC.approve(address(mockRewardManager), 10_000 * 10 ** 6);
        vm.stopPrank();

        // Setup mock proofs
        mockWorldId.setValid(true);
    }

    function testSetup() public view {
        assertEq(eventManager.appId(), APP_ID);
        assertEq(eventManager.actionId(), ACTION_ID);
        assertEq(eventManager.owner(), owner);
    }

    function testCreateEvent() public {
        vm.prank(eventCreator);
        eventManager.createEvent(
            EVENT_NAME,
            EVENT_DESCRIPTION,
            FUTURE_TIMESTAMP,
            address(mockUSDC),
            EventManager.RewardType.TOKEN,
            EventManager.TokenType.USDC,
            REWARD_AMOUNT
        );

        EventManager.Event memory event0 = eventManager.getEvent(0);
        assertEq(event0.name, EVENT_NAME);
        assertEq(event0.description, EVENT_DESCRIPTION);
        assertEq(event0.timestamp, FUTURE_TIMESTAMP);
        assertEq(event0.creator, eventCreator);
        assertEq(event0.participants.length, 0);
    }

    function testCreateNFTEvent() public {
        vm.prank(eventCreator);
        eventManager.createEvent(
            EVENT_NAME,
            EVENT_DESCRIPTION,
            FUTURE_TIMESTAMP,
            address(mockRewardManager),
            EventManager.RewardType.NFT,
            EventManager.TokenType.USDC,
            REWARD_AMOUNT
        );

        EventManager.Event memory event0 = eventManager.getEvent(0);
        assertEq(event0.name, EVENT_NAME);
        assertEq(event0.description, EVENT_DESCRIPTION);
        assertEq(event0.timestamp, FUTURE_TIMESTAMP);
        assertEq(event0.creator, eventCreator);
        assertEq(event0.participants.length, 0);
    }

    function testFailCreateEventPastTimestamp() public {
        vm.prank(eventCreator);
        eventManager.createEvent(
            EVENT_NAME,
            EVENT_DESCRIPTION,
            block.timestamp - 1,
            address(mockUSDC),
            EventManager.RewardType.TOKEN,
            EventManager.TokenType.USDC,
            REWARD_AMOUNT
        );
    }

    function testRegisterParticipant() public {
        // First create an event
        testCreateEvent();

        // Register participant
        vm.prank(user1);
        uint256[8] memory proof;
        eventManager.registerParticipant(0, 12_345, proof);

        // Verify registration
        EventManager.Event memory event0 = eventManager.getEvent(0);
        assertEq(event0.participants.length, 1);
        assertEq(event0.participants[0], user1);
    }

    function testFailRegisterParticipantTwice() public {
        testCreateEvent();

        vm.expectRevert("Already registered as participant");

        vm.startPrank(user1);
        uint256[8] memory proof;

        eventManager.registerParticipant(0, 12_345, proof);
        eventManager.registerParticipant(0, 12_345, proof);

        vm.stopPrank();
    }

    function testSetTokenRewardForParticipant() public {
        testCreateEvent();

        // Register participant
        vm.prank(user1);
        uint256[8] memory proof;
        eventManager.registerParticipant(0, 12_345, proof);

        // Set reward
        vm.prank(eventCreator);
        eventManager.setTokenRewardForParticipant(0, user1, REWARD_AMOUNT);

        uint256 distributedReward = mockRewardManager.getUserTokenReward(
            0,
            address(user1)
        );

        assertEq(distributedReward, REWARD_AMOUNT);
    }

    function testFailSetTokenRewardForNonParticipant() public {
        testCreateEvent();

        eventManager.setTokenRewardForParticipant(0, user1, REWARD_AMOUNT);
    }

    function testClaimReward() public {
        // Create event
        testCreateEvent();

        mockUSDC.mint(address(mockRewardManager), REWARD_AMOUNT * 2);
        vm.prank(address(mockRewardManager));
        mockUSDC.approve(address(eventManager), type(uint256).max);

        // Register participant
        vm.prank(user1);
        uint256[8] memory proof;
        eventManager.registerParticipant(0, 12_345, proof);

        vm.prank(eventCreator);
        eventManager.setTokenRewardForParticipant(0, user1, REWARD_AMOUNT);

        uint256 userBal = mockUSDC.balanceOf(address(user1));

        // Claim reward
        vm.prank(user1);
        eventManager.claimReward(0, 54_321, proof);

        uint256 userAfter = mockUSDC.balanceOf(address(user1));
        assertEq(userAfter, userBal + REWARD_AMOUNT);
    }

    function testUpdateEventTokenReward() public {
        testCreateEvent();

        uint256 creatorBal = mockUSDC.balanceOf(address(eventCreator));

        uint256 newRewardAmount = 200;
        vm.prank(eventCreator);
        eventManager.updateEventTokenReward(0, newRewardAmount);

        uint256 creatorAfter = mockUSDC.balanceOf(address(eventCreator));

        assertLt(creatorAfter, creatorBal);
    }

    function testBulkRewardDistribution() public {
        testCreateEvent();

        // Register participants
        uint256[8] memory proof;

        vm.prank(user1);
        eventManager.registerParticipant(0, 12_345, proof);

        vm.prank(user2);
        eventManager.registerParticipant(0, 123_456, proof);

        // Setup bulk reward data
        address[] memory participants = new address[](2);
        participants[0] = user1;
        participants[1] = user2;

        uint256[] memory rewards = new uint256[](2);
        rewards[0] = REWARD_AMOUNT;
        rewards[1] = REWARD_AMOUNT;

        // Distribute rewards
        vm.prank(eventCreator);
        eventManager.updateEventTokenReward(0, 1000);

        vm.expectEmit(true, true, true, true);
        emit BulkTokenRewardSet(0, participants, rewards);

        vm.prank(eventCreator);
        eventManager.setBulkRewardsForParticipants(0, participants, rewards);
    }

    function testClaimNFTReward() public {
        testCreateNFTEvent();

        vm.prank(owner);
        eventManager.setEventNFTAddress(address(mockEventNFT));

        uint256[8] memory proof;
        vm.prank(user1);
        eventManager.registerParticipant(0, 12_345, proof);

        vm.prank(user1);

        (bool isClaimed, address caller, uint256 tokenId) = eventManager
            .claimNFTReward(0, 54_321, proof);

        assertTrue(isClaimed);
        assertEq(caller, user1);
        assertEq(mockEventNFT.ownerOf(tokenId), user1);
        assertTrue(mockEventNFT.hasClaimedNFT(user1));
    }

    function testClaimNFTBonusReward() public {
        testCreateNFTEvent();

        vm.prank(owner);
        eventManager.setEventNFTAddress(address(mockEventNFT));

        uint256[8] memory proof;
        vm.prank(user1);
        eventManager.registerParticipant(0, 12_345, proof);
        vm.prank(user2);
        eventManager.registerParticipant(0, 12_346, proof);

        vm.prank(user1);
        (bool isClaimed, address caller, uint256 tokenId) = eventManager
            .claimNFTReward(0, 54_321, proof);

        assertTrue(isClaimed);
        assertEq(caller, user1);
        assertEq(mockEventNFT.ownerOf(tokenId), user1);
        assertTrue(mockEventNFT.hasClaimedNFT(user1));
        assertTrue(mockEventNFT.hasClaimedBonusNFT(user1));
    }

    function testFailClaimNFTRewardForTokenEvent() public {
        testCreateEvent();

        vm.prank(owner);
        eventManager.setEventNFTAddress(address(mockEventNFT));

        uint256[8] memory proof;
        vm.prank(user1);
        eventManager.registerParticipant(0, 12_345, proof);

        vm.prank(user1);

        (bool isClaimed, address caller, uint256 tokenId) = eventManager
            .claimNFTReward(0, 54_321, proof);

        assertTrue(isClaimed);
        assertEq(caller, user1);
        assertEq(mockEventNFT.ownerOf(tokenId), user1);
        assertTrue(mockEventNFT.hasClaimedNFT(user1));
    }

    function testGiveFirstParticipantTokenBonus() public {
        testCreateEvent();

        // Register participant

        uint256[8] memory proof;
        vm.prank(user1);
        eventManager.registerParticipant(0, 12_345, proof);

        vm.prank(user2);
        eventManager.registerParticipant(0, 12_346, proof);

        // Set reward
        vm.startPrank(eventCreator);
        uint256 newRewardAmount = 200;
        eventManager.updateEventTokenReward(0, newRewardAmount);
        eventManager.setTokenRewardForParticipant(0, user1, REWARD_AMOUNT);
        eventManager.setTokenRewardForParticipant(0, user2, REWARD_AMOUNT);

        eventManager.giveFirstParticipantTokenBonus(0, BONUSTOKEN);
        vm.stopPrank();

        uint256 distributedReward = mockRewardManager.getUserTokenReward(
            0,
            address(user1)
        );
        console.log(distributedReward);

 main
    // Assert
    vm.expectRevert("Already registered as participant");
    eventManager.registerParticipant(0, nullifierHash, proof);
  }

  function testCreateRewardSuccess() public {
        // Create an event first
        eventManager.createEvent("Test Event", "Description", block.timestamp + 1 days, "NFT+Token");
        
        // Prepare reward parameters
        string memory nftName = "Event NFT";
        string memory nftSymbol = "ENFT";
        uint256 maxSupply = 100;
        string memory baseURI = "ipfs://QmTest/";
        EventRewardManager.TokenType tokenType = EventRewardManager.TokenType.USDC;
        uint256 rewardAmount = 1000;

        // Expect RewardCreated event
        vm.expectEmit(true, true, true, true);
        emit RewardCreated(
            0, // eventId
            address(0), // NFT address will be determined at runtime
            USDC_TOKEN,
            tokenType,
            rewardAmount
        );

        // Create reward
        address nftAddress = eventManager.createReward(
            0, // eventId
            nftName,
            nftSymbol,
            maxSupply,
            baseURI,
            tokenType,
            USDC_TOKEN,
            rewardAmount
        );

        // Verify reward was created correctly
        EventManager.EventReward memory reward = eventManager.getEventReward(0);
        assertEq(reward.nftAddress, nftAddress);
        assertEq(reward.tokenAddress, USDC_TOKEN);
        assertEq(uint(reward.rewardType), uint(EventRewardManager.TokenType.USDC));
        assertEq(reward.tokenRewardAmount, rewardAmount);
        assertTrue(reward.isActive);
    }

=======
        assertEq(distributedReward, REWARD_AMOUNT + 10);
    }
main
}
