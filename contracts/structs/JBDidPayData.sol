// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @custom:member payer The address the payment originated from.
/// @custom:member projectId The ID of the project the payment was made to.
/// @custom:member rulesetId The ID of the ruleset the payment is being made during.
/// @custom:member amount The amount of the payment. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member forwardedAmount The amount of the payment that is being sent to the pay hook. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member weight The current ruleset's weight used to determine how many tokens are being minted.
/// @custom:member projectTokenCount The number of project tokens minted for the beneficiary.
/// @custom:member beneficiary The address the tokens were minted to.
/// @custom:member hookMetadata Extra data specified by the data hook, which is sent to the pay hook.
/// @custom:member payerMetadata Extra data specified by the payer, which is sent to the pay hook.
struct JBDidPayData {
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
}
