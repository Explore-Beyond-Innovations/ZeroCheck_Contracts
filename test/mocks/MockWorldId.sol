// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {IWorldID} from "../../src/interfaces/IWorldID.sol";

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
        require(isValid, "Mock WorldID: Invalid proof");
        if (nullifierHashes[nullifierHash]) {
            revert InvalidNullifier();
        }
        require(root != 0, "Mock WorldID: Invalid root");
        require(groupId != 0, "Mock WorldID: Invalid group ID");
        require(signal != 0, "Mock WorldID: Invalid signal");
        require(nullifierHash != 0, "Mock WorldID: Invalid nullifier hash");
        require(externalNullifier != 0, "Mock WorldID: Invalid external nullifier");
        require(proof.length == 8, "Mock WorldID: Invalid proof length");
    }

    function registerNullifier(uint256 nullifierHash) external {
        nullifierHashes[nullifierHash] = true;
    }

    function isNullifierUsed(uint256 nullifierHash) external view returns (bool) {
        return nullifierHashes[nullifierHash];
    }
}
