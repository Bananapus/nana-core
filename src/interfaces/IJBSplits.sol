// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBSplit} from "./../structs/JBSplit.sol";
import {JBSplitGroup} from "./../structs/JBSplitGroup.sol";
import {IJBProjects} from "./IJBProjects.sol";

interface IJBSplits {
    event SetSplit(
        uint256 indexed projectId, uint256 indexed rulesetId, uint256 indexed group, JBSplit split, address caller
    );

    function FALLBACK_RULESET_ID() external view returns (uint256);

    function splitsOf(uint256 projectId, uint256 rulesetId, uint256 group) external view returns (JBSplit[] memory);

    function setSplitGroupsOf(uint256 projectId, uint256 rulesetId, JBSplitGroup[] memory splitGroups) external;
}
