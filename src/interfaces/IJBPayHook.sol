// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {JBDidPayContext} from "./../structs/JBDidPayContext.sol";

/// @title Pay hook
/// @notice Hook called after a terminal's `pay(...)` logic completes (if passed by the ruleset's data hook)
interface IJBPayHook is IERC165 {
    /// @notice This function is called by the terminal's `pay(...)` function after the execution of its logic.
    /// @dev Critical business logic should be protected by appropriate access control.
    /// @param data the data passed by the terminal, as a `JBDidPayContext` struct.
    function didPay(JBDidPayContext calldata data) external payable;
}
