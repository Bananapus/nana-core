// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @custom:member payer The address from which the payment originated.
/// @custom:member projectId The ID of the project for which the payment was made.
/// @custom:member currentFundingCycleConfiguration The configuration of the funding cycle during which the payment is being made.
/// @custom:member amount The amount of the payment. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member forwardedAmount The amount of the payment that is being sent to the delegate. Includes the token being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member weight The current funding cycle's weight used to determine how many tokens are being minted.
/// @custom:member projectTokenCount The number of project tokens minted for the beneficiary.
/// @custom:member beneficiary The address to which the tokens were minted.
/// @custom:member dataSourceMetadata Extra data to send to the delegate sent by the data source.
/// @custom:member payerMetadata Extra data to send to the delegate sent by the payer.
struct JBDidPayData3_1_1 {
    address payer;
    uint256 projectId;
    uint256 currentFundingCycleConfiguration;
    JBTokenAmount amount;
    JBTokenAmount forwardedAmount;
    uint256 weight;
    uint256 projectTokenCount;
    address beneficiary;
    bytes dataSourceMetadata;
    bytes payerMetadata;
}