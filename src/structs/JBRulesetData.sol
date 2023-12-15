// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBRulesetApprovalHook} from "./../interfaces/IJBRulesetApprovalHook.sol";

/// @custom:member duration The number of seconds the ruleset lasts for, after which a new ruleset will start. A
/// duration of 0 means that the ruleset will stay active until the project owner explicitly issues a reconfiguration,
/// at which point a new ruleset will immediately start with the updated properties. If the duration is greater than 0,
/// a project owner cannot make changes to a ruleset's parameters while it is active – any proposed changes will apply
/// to the subsequent ruleset. If no changes are proposed, a ruleset rolls over to another one with the same properties
/// but new `start` timestamp and a decayed `weight`.
/// @custom:member weight A fixed point number with 18 decimals that contracts can use to base arbitrary calculations
/// on. For example, payment terminals can use this to determine how many tokens should be minted when a payment is
/// received.
/// @custom:member decayRate A percent by how much the `weight` of the subsequent ruleset should be reduced, if the
/// project owner hasn't queued the subsequent ruleset with an explicit `weight`. If it's 0, each ruleset will have
/// equal weight. If the number is 90%, the next ruleset will have a 10% smaller weight. This weight is out of
/// `JBConstants.MAX_DECAY_RATE`.
/// @custom:member hook An address of a contract that says whether a proposed ruleset should be accepted or rejected. It
/// can be used to create rules around how a project owner can change ruleset parameters over time.
struct JBRulesetData {
    uint256 duration;
    uint256 weight;
    uint256 decayRate;
    IJBRulesetApprovalHook hook;
}
