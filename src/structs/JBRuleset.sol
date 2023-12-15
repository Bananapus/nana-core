// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBRulesetApprovalHook} from "./../interfaces/IJBRulesetApprovalHook.sol";

/// @dev `JBRuleset` timestamps are unix timestamps (seconds since 00:00 January 1st, 1970 UTC).
/// @custom:member cycleNumber The ruleset's cycle number. Each ruleset's `cycleNumber` is the previous ruleset's
/// `cycleNumber` plus one. Each project's first ruleset has a `cycleNumber` of 1.
/// @custom:member id The ruleset's ID, which is a timestamp of when this ruleset's rules were initialized. The
/// `rulesetId` stays the same for rulesets that automatically cycle over from a manually queued ruleset.
/// @custom:member basedOnId The `rulesetId` of the ruleset which was active when this ruleset was created.
/// @custom:member start The timestamp from which this ruleset is considered active.
/// @custom:member duration The number of seconds the ruleset lasts for. After this duration, a new ruleset will start.
/// The project owner can queue new rulesets at any time, which will take effect once the current ruleset's duration is
/// over. If the `duration` is 0, newly queued rulesets will take effect immediately. If a ruleset ends and there are no
/// new rulesets queued, the current ruleset cycles over to another one with the same properties but a new `start`
/// timestamp and a `weight` reduced by the ruleset's `decayRate`.
/// @custom:member weight A fixed point number with 18 decimals which is typically used by payment terminals to
/// determine how many tokens should be minted when a payment is received. This can be used by other contracts for
/// arbitrary calculations.
/// @custom:member decayRate The percentage by which to reduce the `weight` each time a new ruleset starts. `weight` is
/// a percentage out of `JBConstants.MAX_DECAY_RATE`. If it's 0, the next ruleset will have the same `weight` by
/// default. If it's 90%, the next ruleset's `weight` will be 10% smaller. If a ruleset explicitly sets a new `weight`,
/// the `decayRate` doesn't apply.
/// @custom:member hook An address of a contract that says whether a queued ruleset should be approved or rejected. If a
/// ruleset is rejected, it won't go into effect. An approval hook can be used to create rules which dictate how a
/// project owner can change their ruleset over time.
/// @custom:member metadata Extra data associated with a ruleset which can be used by other contracts.
struct JBRuleset {
    uint256 cycleNumber;
    uint256 id;
    uint256 basedOnId;
    uint256 start;
    uint256 duration;
    uint256 weight;
    uint256 decayRate;
    IJBRulesetApprovalHook hook;
    uint256 metadata;
}
