// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBDirectoryAccessControl {
    function setControllerAllowed(uint256 projectId) external view returns (bool);
    function setTerminalsAllowed(uint256 projectId) external view returns (bool);
}
