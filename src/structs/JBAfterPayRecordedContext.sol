// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBPayHookSpecification} from "./JBPayHookSpecification.sol";
import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @custom:member payer The address the payment originated from.
/// @custom:member projectId The ID of the project being paid.
/// @custom:member rulesetId The ID of the ruleset the payment is being made during.
/// @custom:member amount The payment's token amount. Includes the token being paid, the value, the number of decimals
/// included, and the currency of the amount.
/// @custom:member forwardedAmount The token amount being forwarded to the pay hook. Includes the token
/// being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member weight The current ruleset's weight (used to determine how many tokens should be minted).
/// @custom:member projectTokenCount The number of project tokens minted for the beneficiary.
/// @custom:member beneficiary The address which receives any tokens this payment yields.
/// @custom:member hookMetadata Extra data specified by the data hook, which is sent to the pay hook.
/// @custom:member payerMetadata Extra data specified by the payer, which is sent to the pay hook.
/// @custom:member specifications The specifications of pay hooks.
struct JBAfterPayRecordedContext {
    address payer;
    uint256 projectId;
    uint256 rulesetId;
    JBTokenAmount amount;
    JBTokenAmount forwardedAmount;
    uint256 weight;
    uint256 projectTokenCount;
    address beneficiary;
    bytes hookMetadata;
    bytes payerMetadata;
    JBPayHookSpecification[] specifications;
}
