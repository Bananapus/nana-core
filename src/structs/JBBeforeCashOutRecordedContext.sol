// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @notice Context sent from the terminal to the ruleset's data hook upon cash out.
/// @custom:member terminal The terminal that is facilitating the cash out.
/// @custom:member holder The holder of the tokens being cashed out.
/// @custom:member projectId The ID of the project whose tokens are being cashed out.
/// @custom:member rulesetId The ID of the ruleset the cash out is being made during.
/// @custom:member cashOutCount The number of tokens being cashed out, as a fixed point number with 18 decimals.
/// @custom:member totalSupply The total token supply being used for the calculation, as a fixed point number with 18
/// decimals.
/// @custom:member surplus The surplus amount used for the calculation, as a fixed point number with 18 decimals.
/// Includes the token of the surplus, the surplus value, the number of decimals
/// included, and the currency of the surplus.
/// @custom:member useTotalSurplus If surplus across all of a project's terminals is being used when making cash outs.
/// @custom:member cashOutTaxRate The cash out tax rate of the ruleset the cash out is being made during.
/// @custom:member metadata Extra data provided by the casher.
struct JBBeforeCashOutRecordedContext {
    address terminal;
    address holder;
    uint256 projectId;
    uint256 rulesetId;
    uint256 cashOutCount;
    uint256 totalSupply;
    JBTokenAmount surplus;
    bool useTotalSurplus;
    uint256 cashOutTaxRate;
    bytes metadata;
}
