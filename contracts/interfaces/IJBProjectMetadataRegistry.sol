// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBProjectMetadataRegistry {
    function metadataOf(uint256 projectId) external view returns (string memory);
    function setMetadataOf(uint256 projectId, string calldata metadata) external;
}
