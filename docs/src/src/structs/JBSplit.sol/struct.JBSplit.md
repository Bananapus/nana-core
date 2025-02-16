# JBSplit
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBSplit.sol)

Splits are used to send a percentage of a total token amount to a specific contract, project, or address.
Splits are used to send payouts and reserved tokens.

*1. If a non-zero split hook contract is specified, this split's tokens are sent there along with this split's
properties.*

*2. Otherwise, if a non-zero project ID is specified, this split's tokens are used to `pay` it through its
terminal if possible, or sent to the project's owner if not. If this payment yields tokens, those go to the split's
`beneficiary`.*

*3. Otherwise, this split's tokens are sent directly to the `beneficiary`.*

*To summarize, this split's tokens are sent according to the following priority: `split hook` > `projectId` >
`beneficiary`.*

**Notes:**
- member: percent The percent of the total token amount that this split sends. This number is out of
`JBConstants.SPLITS_TOTAL_PERCENT`.

- member: projectId The ID of a project to `pay`, if applicable. Resulting tokens will be routed to the
`beneficiary`.

- member: beneficiary Receives this split's tokens if the `hook` and `projectId` are zero. If the `projectId`
is specified, the `beneficiary` receives any project tokens minted by this split.

- member: preferAddToBalance If this split were to `pay` a project through its terminal, this flag indicates
whether it should prefer using the terminal's `addToBalance` function instead.

- member: lockedUntil The split cannot be changed until this timestamp. The `lockedUntil` timestamp can be
increased while a split is locked. If `lockedUntil` is zero, this split can be changed at any time.

- member: hook A contract which will receive this split's tokens and properties, and can define custom
behavior.


```solidity
struct JBSplit {
    uint32 percent;
    uint64 projectId;
    address payable beneficiary;
    bool preferAddToBalance;
    uint48 lockedUntil;
    IJBSplitHook hook;
}
```

