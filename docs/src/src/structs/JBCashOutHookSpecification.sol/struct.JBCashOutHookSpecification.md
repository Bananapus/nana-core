# JBCashOutHookSpecification
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBCashOutHookSpecification.sol)

A cash out hook specification sent from the ruleset's data hook back to the terminal. This specification is
fulfilled by the terminal.

**Notes:**
- member: hook The cash out hook to use when fulfilling this specification.

- member: amount The amount to send to the hook.

- member: metadata Metadata to pass to the hook.


```solidity
struct JBCashOutHookSpecification {
    IJBCashOutHook hook;
    uint256 amount;
    bytes metadata;
}
```

