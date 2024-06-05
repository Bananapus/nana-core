// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBSplit} from "./JBSplit.sol";

/// @custom:member token The token being sent to the split hook.
/// @custom:member amount The amount being sent to the split hook, as a fixed point number.
/// @custom:member decimals The number of decimals in the amount.
/// @custom:member projectId The project the split belongs to.
/// @custom:member groupId The group the split belongs to. By convention, this ID is `uint256(uint160(tokenAddress))` for payouts and `1` for reserved tokens.
/// @custom:member split The split which specified the hook.
struct JBSplitHookContext {
    address token;
    uint256 amount;
    uint256 decimals;
    uint256 projectId;
    uint256 groupId;
    JBSplit split;
}
