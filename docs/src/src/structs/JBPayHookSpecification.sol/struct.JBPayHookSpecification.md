# JBPayHookSpecification
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBPayHookSpecification.sol)

A pay hook specification sent from the ruleset's data hook back to the terminal. This specification is
fulfilled by the terminal.

**Notes:**
- member: hook The pay hook to use when fulfilling this specification.

- member: amount The amount to send to the hook.

- member: metadata Metadata to pass the hook.


```solidity
struct JBPayHookSpecification {
    IJBPayHook hook;
    uint256 amount;
    bytes metadata;
}
```

