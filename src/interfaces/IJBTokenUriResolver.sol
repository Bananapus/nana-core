// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBTokenUriResolver {
    function getUriFor(uint32 projectId) external view returns (string memory tokenUri);
}
