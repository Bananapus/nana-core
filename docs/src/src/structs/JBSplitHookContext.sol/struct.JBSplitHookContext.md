# JBSplitHookContext
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBSplitHookContext.sol)

**Notes:**
- member: token The token being sent to the split hook.

- member: amount The amount being sent to the split hook, as a fixed point number.

- member: decimals The number of decimals in the amount.

- member: projectId The project the split belongs to.

- member: groupId The group the split belongs to. By convention, this ID is `uint256(uint160(tokenAddress))`
for payouts and `1` for reserved tokens.

- member: split The split which specified the hook.


```solidity
struct JBSplitHookContext {
    address token;
    uint256 amount;
    uint256 decimals;
    uint256 projectId;
    uint256 groupId;
    JBSplit split;
}
```

