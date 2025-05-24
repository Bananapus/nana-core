// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBBeforePayRecordedContext} from "./../structs/JBBeforePayRecordedContext.sol";
import {JBBeforeCashOutRecordedContext} from "./../structs/JBBeforeCashOutRecordedContext.sol";
import {JBCashOutHookSpecification} from "./../structs/JBCashOutHookSpecification.sol";
import {JBPayHookSpecification} from "./../structs/JBPayHookSpecification.sol";

/// @notice Data hooks can extend a terminal's core pay/cashout functionality by overriding the weight or memo. They can
/// also specify pay/cashout hooks for the terminal to fulfill, or allow addresses to mint a project's tokens on-demand.
/// @dev If a project's ruleset has `useDataHookForPay` or `useDataHookForCashOut` enabled, its `dataHook` is called by
/// the terminal upon payments/cashouts (respectively).
interface IJBRulesetDataHook4_2 is IERC165 {
    /// @notice A flag indicating whether an address has permission to mint a project's tokens on-demand.
    /// @dev A project's data hook can allow any address to mint its tokens.
    /// @param projectId The ID of the project whose token can be minted.
    /// @param ruleset The ruleset to check the token minting permission of.
    /// @param addr The address to check the token minting permission of.
    /// @return flag A flag indicating whether the address has permission to mint the project's tokens on-demand.
    function hasMintPermissionFor(
        uint256 projectId,
        JBRuleset memory ruleset,
        address addr
    )
        external
        view
        returns (bool flag);

    /// @notice The data calculated before a payment is recorded in the terminal store. This data is provided to the
    /// terminal's `pay(...)` transaction.
    /// @param context The context passed to this data hook by the `pay(...)` function as a `JBBeforePayRecordedContext`
    /// struct.
    /// @return weight The new `weight` to use, overriding the ruleset's `weight`.
    /// @return hookSpecifications The amount and data to send to pay hooks instead of adding to the terminal's balance.
    function beforePayRecordedWith(JBBeforePayRecordedContext calldata context)
        external
        view
        returns (uint256 weight, JBPayHookSpecification[] memory hookSpecifications);

    /// @notice The data calculated before a cash out is recorded in the terminal store. This data is provided to the
    /// terminal's `cashOutTokensOf(...)` transaction.
    /// @param context The context passed to this data hook by the `cashOutTokensOf(...)` function as a
    /// `JBBeforeCashOutRecordedContext` struct.
    /// @return cashOutTaxRate The rate determining the amount that should be reclaimable for a given surplus and token
    /// supply.
    /// @return cashOutCount The amount of tokens that should be considered cashed out.
    /// @return totalSupply The total amount of tokens that are considered to be existing.
    /// @return hookSpecifications The amount and data to send to cash out hooks instead of returning to the
    /// beneficiary.
    function beforeCashOutRecordedWith(JBBeforeCashOutRecordedContext calldata context)
        external
        view
        returns (
            uint256 cashOutTaxRate,
            uint256 cashOutCount,
            uint256 totalSupply,
            JBCashOutHookSpecification[] memory hookSpecifications
        );
}
