// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IWorldID {
    // function verifyProof(
    //   uint256 root,
    //   uint256 nullifierHash,
    //   uint256[8] calldata proof
    // )
    //   external
    //   view;

    /**
     * @notice Verifies a zero-knowledge proof for a given action.
     * @param root The Merkle root of the Semaphore identity tree.
     * @param groupId The ID of the group (e.g., app or use case).
     * @param signal A signal uniquely representing the action being performed.
     * @param nullifierHash A hash ensuring the proof cannot be reused.
     * @param externalNullifier Prevents re-use of the nullifier across actions.
     * @param proof The zero-knowledge proof itself.
     */
    function verifyProof(
        uint256 root,
        uint256 groupId,
        uint256 signal,
        uint256 nullifierHash,
        uint256 externalNullifier,
        uint256[8] calldata proof
    ) external view;
}
