// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {JBAfterRedeemContext} from "./../structs/JBAfterRedeemContext.sol";

/// @notice Hook called after a terminal's `redeemTokensOf(...)` logic completes (if passed by the ruleset's data hook).
interface IJBRedeemHook is IERC165 {
    /// @notice This function is called by the terminal's `redeemTokensOf(...)` function after the execution of its
    /// logic.
    /// @dev Critical business logic should be protected by appropriate access control.
    /// @param context The context passed in by the terminal, as a `JBAfterRedeemContext` struct.
    function afterRedeem(JBAfterRedeemContext calldata context) external payable;
}
