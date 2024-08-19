// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBProjectUriRegistry {
    function uriOf(uint256 projectId) external view returns (string memory);
    function setUriOf(uint256 projectId, string calldata uri) external;
}
