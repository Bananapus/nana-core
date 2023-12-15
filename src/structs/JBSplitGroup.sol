// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBSplit} from "./JBSplit.sol";

/// @custom:member groupId An identifier for the group.
/// @custom:member splits The splits in the group.
struct JBSplitGroup {
    uint256 groupId;
    JBSplit[] splits;
}
