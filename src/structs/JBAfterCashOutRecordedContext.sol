// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @custom:member holder The holder of the tokens being cashed out.
/// @custom:member projectId The ID of the project being cashed out from.
/// @custom:member rulesetId The ID of the ruleset the cash out is being made during.
/// @custom:member cashOutCount The number of project tokens being cashed out.
/// @custom:member cashOutTaxRate The current ruleset's cash out tax rate.
/// @custom:member reclaimedAmount The token amount being reclaimed from the project's terminal balance. Includes the
/// token being
/// reclaimed, the value, the number of decimals included, and the currency of the amount.
/// @custom:member forwardedAmount The token amount being forwarded to the cash out hook. Includes the token
/// being forwarded, the value, the number of decimals included, and the currency of the amount.
/// @custom:member beneficiary The address the reclaimed amount will be sent to.
/// @custom:member hookMetadata Extra data specified by the data hook, which is sent to the cash out hook.
/// @custom:member cashOutMetadata Extra data specified by the account cashing out, which is sent to the cash out hook.
struct JBAfterCashOutRecordedContext {
    address holder;
    uint256 projectId;
    uint256 rulesetId;
    uint256 cashOutCount;
    JBTokenAmount reclaimedAmount;
    JBTokenAmount forwardedAmount;
    uint256 cashOutTaxRate;
    address payable beneficiary;
    bytes hookMetadata;
    bytes cashOutMetadata;
}
