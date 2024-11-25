// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBAfterCashOutRecordedContext} from "./../structs/JBAfterCashOutRecordedContext.sol";

/// @notice Hook called after a terminal's `cashOutTokensOf(...)` logic completes (if passed by the ruleset's data hook).
interface IJBCashOutHook is IERC165 {
    /// @notice This function is called by the terminal's `cashOutTokensOf(...)` function after the cash out has been
    /// recorded in the terminal store.
    /// @dev Critical business logic should be protected by appropriate access control.
    /// @param context The context passed in by the terminal, as a `JBAfterCashOutRecordedContext` struct.
    function afterCashOutRecordedWith(JBAfterCashOutRecordedContext calldata context) external payable;
}
