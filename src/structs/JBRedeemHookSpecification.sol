// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBRedeemHook} from "../interfaces/IJBRedeemHook.sol";

/// @notice A redeem hook specification sent from the ruleset's data hook back to the terminal. This specification is
/// fulfilled by the terminal.
/// @custom:member hook The redeem hook to use when fulfilling this specification.
/// @custom:member amount The amount to send to the hook.
/// @custom:member metadata Metadata to pass to the hook.
struct JBRedeemHookSpecification {
    IJBRedeemHook hook;
    uint256 amount;
    bytes metadata;
}
