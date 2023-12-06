// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./../interfaces/terminal/IJBTerminal.sol";
import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @notice Data sent from the terminal to the ruleset's data hook upon payment.
/// @custom:member terminal The terminal that is facilitating the payment.
/// @custom:member payer The address from which the payment originated.
/// @custom:member amount The amount of the payment. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member projectId The ID of the project being paid.
/// @custom:member rulesetId The ID of the ruleset the payment is being made during.
/// @custom:member beneficiary The specified address that should be the beneficiary of anything that results from the payment.
/// @custom:member weight The weight of the ruleset during which the payment is being made.
/// @custom:member reservedRate The reserved rate of the ruleset during which the payment is being made.
/// @custom:member metadata Extra data specified by the payer.
struct JBPayParamsData {
    address terminal;
    address payer;
    JBTokenAmount amount;
    uint256 projectId;
    uint256 rulesetId;
    address beneficiary;
    uint256 weight;
    uint256 reservedRate;
    bytes metadata;
}
