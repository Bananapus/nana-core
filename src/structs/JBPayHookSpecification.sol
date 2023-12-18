// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPayHook} from "../interfaces/IJBPayHook.sol";

/// @notice A pay hook specification sent from the ruleset's data hook back to the terminal. This specification is
/// fulfilled by the terminal.
/// @custom:member hook The pay hook to use when fulfilling this specification.
/// @custom:member amount The amount to send to the hook.
/// @custom:member metadata Metadata to pass the hook.
struct JBPayHookSpecification {
    IJBPayHook hook;
    uint256 amount;
    bytes metadata;
}
