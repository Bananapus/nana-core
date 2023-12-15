// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPayHook} from "../interfaces/IJBPayHook.sol";

/// @notice Payload sent from the ruleset's data hook back to the terminal upon payment. This payload is forwarded to
/// the specified pay hook.
/// @custom:member hook A pay hook contract to use for subsequent calls.
/// @custom:member amount The amount to send to the hook.
/// @custom:member metadata Metadata to pass the hook.
struct JBPayHookPayload {
    IJBPayHook hook;
    uint256 amount;
    bytes metadata;
}
