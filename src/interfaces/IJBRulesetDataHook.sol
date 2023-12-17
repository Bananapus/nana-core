// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {JBPayHookSpecification} from "./../structs/JBPayHookSpecification.sol";
import {JBPayParamsContext} from "./../structs/JBPayParamsContext.sol";
import {JBRedeemParamsContext} from "./../structs/JBRedeemParamsContext.sol";
import {JBRedeemHookSpecification} from "./../structs/JBRedeemHookSpecification.sol";

/// @notice An extra layer of logic which can be used to provide pay/redeem transactions with a custom weight, a custom
/// memo and/or a pay/redeem hook(s).
/// @dev If included in the current ruleset, the `IJBRulesetDataHook` is called by `JBPayoutRedemptionPaymentTerminal`s
/// upon payments and redemptions.
interface IJBRulesetDataHook is IERC165 {
    /// @notice The data provided to the terminal's `pay(...)` transaction.
    /// @param context The context passed to this data hook by the `pay(...)` function as a `JBPayParamsContext` struct.
    /// @return weight The new `weight` to use, overriding the ruleset's `weight`.
    /// @return hookSpecifications The amount and data to send to pay hooks instead of adding to the terminal's balance.
    function payParamsOf(JBPayParamsContext calldata context)
        external
        view
        returns (uint256 weight, JBPayHookSpecification[] memory hookSpecifications);

    /// @notice The data provided to the terminal's `redeemTokensOf(...)` transaction.
    /// @param context The context passed to this data hook by the `redeemTokensOf(...)` function as a
    /// `JBRedeemParamsContext` struct.
    /// @return reclaimAmount The amount to claim, overriding the terminal logic.
    /// @return hookSpecifications The amount and data to send to redeem hooks instead of returning to the beneficiary.
    function redeemParamsOf(JBRedeemParamsContext calldata context)
        external
        view
        returns (uint256 reclaimAmount, JBRedeemHookSpecification[] memory hookSpecifications);
}
