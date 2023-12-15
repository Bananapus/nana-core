// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBTokenAmount} from "./JBTokenAmount.sol";

/// @custom:member holder The holder of the tokens being redeemed.
/// @custom:member projectId The ID of the project the redeemed tokens are associated with.
/// @custom:member rulesetId The ID of the ruleset the redemption is being made during.
/// @custom:member projectTokenCount The number of project tokens being redeemed.
/// @custom:member redemptionRate The current ruleset's redemption rate.
/// @custom:member reclaimedAmount The amount reclaimed from the project's terminal balance. Includes the token being
/// reclaimed, the value, the number of decimals included, and the currency of the amount.
/// @custom:member forwardedAmount The amount of the payment that is being sent to the redeem hook. Includes the token
/// being paid, the value, the number of decimals included, and the currency of the amount.
/// @custom:member beneficiary The address the reclaimed amount will be sent to.
/// @custom:member hookMetadata Extra data specified by the data hook, which is sent to the redeem hook.
/// @custom:member redeemerMetadata Extra data specified by the redeemer, which is sent to the redeem hook.
struct JBDidRedeemData {
    address holder;
    uint256 projectId;
    uint256 rulesetId;
    uint256 projectTokenCount;
    JBTokenAmount reclaimedAmount;
    JBTokenAmount forwardedAmount;
    uint256 redemptionRate;
    address payable beneficiary;
    bytes hookMetadata;
    bytes redeemerMetadata;
}
