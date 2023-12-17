// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {JBPostRecordPayContext} from "./../structs/JBPostRecordPayContext.sol";

/// @notice Hook called after a terminal's `pay(...)` logic completes (if passed by the ruleset's data hook).
interface IJBPayHook is IERC165 {
    /// @notice This function is called by the terminal's `pay(...)` function after the payment has been recorded in the
    /// terminal store.
    /// @dev Critical business logic should be protected by appropriate access control.
    /// @param context The context passed in by the terminal, as a `JBPostRecordPayContext` struct.
    function postRecordPay(JBPostRecordPayContext calldata context) external payable;
}
