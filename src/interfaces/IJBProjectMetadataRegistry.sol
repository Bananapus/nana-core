// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBProjectMetadataRegistry {
    function metadataOf(uint32 projectId) external view returns (string memory);
    function setMetadataOf(uint32 projectId, string calldata metadata) external;
}
