# IJBSplits
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBSplits.sol)


## Functions
### FALLBACK_RULESET_ID


```solidity
function FALLBACK_RULESET_ID() external view returns (uint256);
```

### splitsOf


```solidity
function splitsOf(uint256 projectId, uint256 rulesetId, uint256 groupId) external view returns (JBSplit[] memory);
```

### setSplitGroupsOf


```solidity
function setSplitGroupsOf(uint256 projectId, uint256 rulesetId, JBSplitGroup[] memory splitGroups) external;
```

## Events
### SetSplit

```solidity
event SetSplit(
    uint256 indexed projectId, uint256 indexed rulesetId, uint256 indexed groupId, JBSplit split, address caller
);
```

