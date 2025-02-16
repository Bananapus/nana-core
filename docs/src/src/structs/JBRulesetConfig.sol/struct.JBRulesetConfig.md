# JBRulesetConfig
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBRulesetConfig.sol)

**Notes:**
- member: mustStartAtOrAfter The earliest time the ruleset can start.

- member: duration The number of seconds the ruleset lasts for, after which a new ruleset will start. A
duration of 0 means that the ruleset will stay active until the project owner explicitly issues a reconfiguration,
at which point a new ruleset will immediately start with the updated properties. If the duration is greater than 0,
a project owner cannot make changes to a ruleset's parameters while it is active – any proposed changes will apply
to the subsequent ruleset. If no changes are proposed, a ruleset rolls over to another one with the same properties
but new `start` timestamp and a cut `weight`.

- member: weight A fixed point number with 18 decimals that contracts can use to base arbitrary calculations
on. For example, payment terminals can use this to determine how many tokens should be minted when a payment is
received.

- member: weightCutPercent A percent by how much the `weight` of the subsequent ruleset should be reduced, if
the
project owner hasn't queued the subsequent ruleset with an explicit `weight`. If it's 0, each ruleset will have
equal weight. If the number is 90%, the next ruleset will have a 10% smaller weight. This weight is out of
`JBConstants.MAX_WEIGHT_CUT_PERCENT`.

- member: approvalHook An address of a contract that says whether a proposed ruleset should be accepted or
rejected. It
can be used to create rules around how a project owner can change ruleset parameters over time.

- member: metadata Metadata specifying the controller-specific parameters that a ruleset can have. These
properties cannot change until the next ruleset starts.

- member: splitGroups An array of splits to use for any number of groups while the ruleset is active.

- member: fundAccessLimitGroups An array of structs which dictate the amount of funds a project can access from
its balance in each payment terminal while the ruleset is active. Amounts are fixed point numbers using the same
number of decimals as the corresponding terminal. The `_payoutLimit` and `_surplusAllowance` parameters must fit in
a `uint232`.


```solidity
struct JBRulesetConfig {
    uint48 mustStartAtOrAfter;
    uint32 duration;
    uint112 weight;
    uint32 weightCutPercent;
    IJBRulesetApprovalHook approvalHook;
    JBRulesetMetadata metadata;
    JBSplitGroup[] splitGroups;
    JBFundAccessLimitGroup[] fundAccessLimitGroups;
}
```

