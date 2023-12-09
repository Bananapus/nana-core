// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBSplit} from "./JBSplit.sol";

/// @custom:member token The token being sent to the split hook.
/// @custom:member amount The amount being sent to the split hook, as a fixed point number.
/// @custom:member decimals The number of decimals in the amount.
/// @custom:member projectId The project the split belongs to.
/// @custom:member groupId The ID of the group that the split belongs to.
/// @custom:member split The split which specified the hook.
struct JBSplitHookPayload {
    address token;
    uint160 amount;
    uint8 decimals;
    uint32 projectId;
    uint160 groupId;
    JBSplit split;
}
