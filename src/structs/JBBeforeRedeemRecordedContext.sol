// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @notice Context sent from the terminal to the ruleset's data hook upon redemption.
/// @custom:member terminal The terminal that is facilitating the redemption.
/// @custom:member holder The holder of the tokens being redeemed.
/// @custom:member projectId The ID of the project whose tokens are being redeemed.
/// @custom:member rulesetId The ID of the ruleset the redemption is being made during.
/// @custom:member redeemCount The number of tokens being redeemed, as a fixed point number with 18 decimals.
/// @custom:member totalSupply The total token supply being used for the calculation, as a fixed point number with 18
/// decimals.
/// @custom:member surplus The surplus amount used for the calculation, as a fixed point number with 18 decimals.
/// Includes the token of the surplus, the surplus value, the number of decimals
/// included, and the currency of the surplus.
/// @custom:member useTotalSurplus If surplus across all of a project's terminals is being used when making redemptions.
/// @custom:member redemptionRate The redemption rate of the ruleset the redemption is being made during.
/// @custom:member metadata Extra data provided by the redeemer.
struct JBBeforeRedeemRecordedContext {
    address terminal;
    address holder;
    uint256 projectId;
    uint256 rulesetId;
    uint256 redeemCount;
    uint256 totalSupply;
    JBTokenAmount surplus;
    bool useTotalSurplus;
    uint256 redemptionRate;
    bytes metadata;
}
