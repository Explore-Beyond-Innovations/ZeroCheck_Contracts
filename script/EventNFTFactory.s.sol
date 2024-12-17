// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import { Script, console } from "forge-std/Script.sol";
import { EventNFTFactory } from "../src/EventNFTFactory.sol";

// This script deploys the EventNFTFactory contract
contract EventNFTFactoryScript is Script {
  function run() public {
    // Deploy the EventNFTFactory contract
    vm.startBroadcast(); // Begin broadcasting transactions (deploying)

    EventNFTFactory factory = new EventNFTFactory();

    console.log("EventNFTFactory deployed at:", address(factory));

    vm.stopBroadcast(); // Stop broadcasting transactions
  }
}
