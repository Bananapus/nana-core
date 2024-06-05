// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBSplit} from "./JBSplit.sol";

/// @custom:member groupId An identifier for the group. By convention, this ID is `uint256(uint160(tokenAddress))` for payouts and `1` for reserved tokens.
/// @custom:member splits The splits in the group.
struct JBSplitGroup {
    uint256 groupId;
    JBSplit[] splits;
}
