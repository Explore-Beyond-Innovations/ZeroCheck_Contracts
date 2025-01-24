// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library ByteHasher {
    /// @dev Creates a keccak256 hash of a bytes array.
    /// @param value The bytes array to hash.
    /// @return The hash of the bytes array.
    function hashToField(bytes memory value) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(value))) >> 8;
    }
}
