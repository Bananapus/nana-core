// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBRulesetData} from "./JBRulesetData.sol";
import {JBRulesetMetadata} from "./JBRulesetMetadata.sol";
import {JBSplitGroup} from "./JBSplitGroup.sol";
import {JBFundAccessLimitGroup} from "./JBFundAccessLimitGroup.sol";

/// @custom:member mustStartAtOrAfter The earliest time the ruleset can start.
/// @custom:member data Data that defines the ruleset. These properties cannot change until the next ruleset starts.
/// @custom:member metadata Metadata specifying the controller-specific parameters that a ruleset can have. These properties cannot change until the next ruleset starts.
/// @custom:member splitGroups An array of splits to use for any number of groups while the ruleset is active.
/// @custom:member fundAccessLimitGroups An array of structs which dictate the amount of funds a project can access from its balance in each payment terminal while the ruleset is active. Amounts are fixed point numbers using the same number of decimals as the corresponding terminal. The `_payoutLimit` and `_surplusAllowance` parameters must fit in a `uint232`.
struct JBRulesetConfig {
    uint256 mustStartAtOrAfter;
    JBRulesetData data;
    JBRulesetMetadata metadata;
    JBSplitGroup[] splitGroups;
    JBFundAccessLimitGroup[] fundAccessLimitGroups;
}
