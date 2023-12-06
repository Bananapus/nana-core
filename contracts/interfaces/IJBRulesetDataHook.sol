// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBPayHookPayload} from "./../structs/JBPayHookPayload.sol";
import {JBPayParamsData} from "./../structs/JBPayParamsData.sol";
import {JBRedeemParamsData} from "./../structs/JBRedeemParamsData.sol";
import {JBRedeemHookPayload} from "./../structs/JBRedeemHookPayload.sol";

/// @notice An extra layer of logic which can be used to provide pay/redeem transactions with a custom weight, a custom memo and/or a pay/redeem hook(s).
/// @dev If included in the current ruleset, the `IJBRulesetDataHook` is called by `JBPayoutRedemptionPaymentTerminal`s upon payments and redemptions.
interface IJBRulesetDataHook is IERC165 {
    /// @notice The data provided to the terminal's `pay(...)` transaction.
    /// @param data The data passed to this data hook by the `pay(...)` function as a `JBPayParamsData` struct.
    /// @return weight The new `weight` to use, overriding the ruleset's `weight`.
    /// @return hookPayloads The amount and data to send to pay hooks instead of adding to the terminal's balance.
    function payParams(JBPayParamsData calldata data)
        external
        view
        returns (uint256 weight, JBPayHookPayload[] memory hookPayloads);

    /// @notice The data provided to the terminal's `redeemTokensOf(...)` transaction.
    /// @param data The data passed to this data hook by the `redeemTokensOf(...)` function as a `JBRedeemParamsData` struct.
    /// @return reclaimAmount The amount to claim, overriding the terminal logic.
    /// @return hookPayloads The amount and data to send to redeem hooks instead of returning to the beneficiary.
    function redeemParams(JBRedeemParamsData calldata data)
        external
        view
        returns (uint256 reclaimAmount, JBRedeemHookPayload[] memory hookPayloads);
}
