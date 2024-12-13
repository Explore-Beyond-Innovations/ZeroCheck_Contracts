// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/EventRewardManager.sol";

contract EventRewardManagerTest {
    EventRewardManager public rewardManager;
    MockERC20 public usdcToken;
    MockERC20 public wldToken;
    address public owner;
    address public participant;

    function setUp() public {
        owner = address(this);
        participant = address(0x1337);

        usdcToken = new MockERC20("USDC", "USDC", 6);
        wldToken = new MockERC20("WLD", "WLD", 18);

        rewardManager = new EventRewardManager();
    }

    function testSetupUSDCTokenReward() public {
        uint256 eventId = 1;
        uint256 rewardAmount = 1000 * 10 ** 6; // 1000 USDC

        rewardManager.setupTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            rewardAmount
        );

        // Verify token reward setup
        (
            EventRewardManager.TokenType tokenType,
            address tokenAddress,
            uint256 eventRewardAmount,
            uint256 totalRewardPool
        ) = rewardManager.eventTokenRewards(eventId);

        assert(tokenType == EventRewardManager.TokenType.USDC);
        assert(tokenAddress == address(usdcToken));
        assert(eventRewardAmount == rewardAmount);
        assert(totalRewardPool == 0);
    }

    function testTransferTokenReward() public {
        uint256 eventId = 1;
        uint256 initialReward = 1000 * 10 ** 6; // 1000 USDC
        uint256 additionalDeposit = 500 * 10 ** 6; // 500 USDC

        rewardManager.setupTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            initialReward
        );

        // Mint tokens to test contract and increase manager contract allowance
        usdcToken.mint(address(this), additionalDeposit);
        usdcToken.approve(address(rewardManager), additionalDeposit);

        rewardManager.transferTokenReward(eventId, additionalDeposit);

        // Verify total reward pool increased
        (, , , uint256 totalRewardPool) = rewardManager.eventTokenRewards(
            eventId
        );
        assert(totalRewardPool == additionalDeposit);
    }

    function testDistributeTokenReward() public {
        uint256 eventId = 1;
        uint256 initialReward = 1000 * 10 ** 6; // 1000 USDC
        uint256 participantReward = 100 * 10 ** 6; // 100 USDC

        // Setup initial reward
        rewardManager.setupTokenReward(
            eventId,
            EventRewardManager.TokenType.USDC,
            address(usdcToken),
            initialReward
        );

        usdcToken.mint(address(rewardManager), initialReward);

        // Distribute reward to participant
        rewardManager.distributeTokenReward(
            eventId,
            participant,
            participantReward
        );

        // Verify participant received tokens
        assert(usdcToken.balanceOf(participant) == participantReward);
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
