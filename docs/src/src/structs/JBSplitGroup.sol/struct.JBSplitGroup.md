# JBSplitGroup
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBSplitGroup.sol)

**Notes:**
- member: groupId An identifier for the group. By convention, this ID is `uint256(uint160(tokenAddress))` for
payouts and `1` for reserved tokens.

- member: splits The splits in the group.


```solidity
struct JBSplitGroup {
    uint256 groupId;
    JBSplit[] splits;
}
```

