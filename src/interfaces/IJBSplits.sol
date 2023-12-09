// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBSplitGroup} from "./../structs/JBSplitGroup.sol";
import {JBSplit} from "./../structs/JBSplit.sol";
import {IJBDirectory} from "./IJBDirectory.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBControlled} from "./IJBControlled.sol";

interface IJBSplits is IJBControlled {
    event SetSplit(
        uint32 indexed projectId, uint40 indexed domainId, uint160 indexed groupId, JBSplit split, address caller
    );

    function splitsOf(uint32 projectId, uint40 domainId, uint160 groupId) external view returns (JBSplit[] memory);

    function setSplitGroupsOf(uint32 projectId, uint40 domainId, JBSplitGroup[] memory splitGroups) external;
}
