// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import "forge-std/Test.sol";
import "../src/EventNFTFactory.sol";
import "../src/EventNFT.sol";

contract EventNFTFactoryTest is Test {
    EventNFTFactory public factory;
    address public owner;
    address public user;

    function setUp() public {
        owner = address(this);
        user = address(0x1);
        factory = new EventNFTFactory();
    }
}