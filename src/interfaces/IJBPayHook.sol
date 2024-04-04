// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBAfterPayRecordedContext} from "./../structs/JBAfterPayRecordedContext.sol";

/// @notice Hook called after a terminal's `pay(...)` logic completes (if passed by the ruleset's data hook).
interface IJBPayHook is IERC165 {
    /// @notice This function is called by the terminal's `pay(...)` function after the payment has been recorded in the
    /// terminal store.
    /// @dev Critical business logic should be protected by appropriate access control.
    /// @param context The context passed in by the terminal, as a `JBAfterPayRecordedContext` struct.
    /// @return metadata The metadata to pass to the next redeem hook.
    function afterPayRecordedWith(JBAfterPayRecordedContext calldata context) external payable returns (bytes memory metadata);
}
