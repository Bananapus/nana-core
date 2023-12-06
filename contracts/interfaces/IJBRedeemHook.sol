// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBDidRedeemData} from "./../structs/JBDidRedeemData.sol";

/// @title Redemption hook
/// @notice Hook called after a terminal's `redeemTokensOf(...)` logic completes (if passed by the ruleset's data hook)
interface IJBRedeemHook is IERC165 {
    /// @notice This function is called by the terminal's `redeemTokensOf(...)` function after the execution of its logic.
    /// @dev Critical business logic should be protected by appropriate access control.
    /// @param data The data passed by the terminal, as a `JBDidRedeemData` struct.
    function didRedeem(JBDidRedeemData calldata data) external payable;
}
