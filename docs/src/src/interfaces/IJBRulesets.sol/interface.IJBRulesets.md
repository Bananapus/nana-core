# IJBRulesets
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBRulesets.sol)


## Functions
### latestRulesetIdOf


```solidity
function latestRulesetIdOf(uint256 projectId) external view returns (uint256);
```

### currentApprovalStatusForLatestRulesetOf


```solidity
function currentApprovalStatusForLatestRulesetOf(uint256 projectId) external view returns (JBApprovalStatus);
```

### currentOf


```solidity
function currentOf(uint256 projectId) external view returns (JBRuleset memory ruleset);
```

### deriveCycleNumberFrom


```solidity
function deriveCycleNumberFrom(
    uint256 baseRulesetCycleNumber,
    uint256 baseRulesetStart,
    uint256 baseRulesetDuration,
    uint256 start
)
    external
    returns (uint256);
```

### deriveStartFrom


```solidity
function deriveStartFrom(
    uint256 baseRulesetStart,
    uint256 baseRulesetDuration,
    uint256 mustStartAtOrAfter
)
    external
    view
    returns (uint256 start);
```

### deriveWeightFrom


```solidity
function deriveWeightFrom(
    uint256 projectId,
    uint256 baseRulesetStart,
    uint256 baseRulesetDuration,
    uint256 baseRulesetWeight,
    uint256 baseRulesetWeightCutPercent,
    uint256 baseRulesetCacheId,
    uint256 start
)
    external
    view
    returns (uint256 weight);
```

### getRulesetOf


```solidity
function getRulesetOf(uint256 projectId, uint256 rulesetId) external view returns (JBRuleset memory);
```

### latestQueuedOf


```solidity
function latestQueuedOf(uint256 projectId)
    external
    view
    returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus);
```

### allOf


```solidity
function allOf(
    uint256 projectId,
    uint256 startingId,
    uint256 size
)
    external
    view
    returns (JBRuleset[] memory rulesets);
```

### upcomingOf


```solidity
function upcomingOf(uint256 projectId) external view returns (JBRuleset memory ruleset);
```

### queueFor


```solidity
function queueFor(
    uint256 projectId,
    uint256 duration,
    uint256 weight,
    uint256 weightCutPercent,
    IJBRulesetApprovalHook approvalHook,
    uint256 metadata,
    uint256 mustStartAtOrAfter
)
    external
    returns (JBRuleset memory ruleset);
```

### updateRulesetWeightCache


```solidity
function updateRulesetWeightCache(uint256 projectId) external;
```

## Events
### RulesetInitialized

```solidity
event RulesetInitialized(
    uint256 indexed rulesetId, uint256 indexed projectId, uint256 indexed basedOnId, address caller
);
```

### RulesetQueued

```solidity
event RulesetQueued(
    uint256 indexed rulesetId,
    uint256 indexed projectId,
    uint256 duration,
    uint256 weight,
    uint256 weightCutPercent,
    IJBRulesetApprovalHook approvalHook,
    uint256 metadata,
    uint256 mustStartAtOrAfter,
    address caller
);
```

### WeightCacheUpdated

```solidity
event WeightCacheUpdated(uint256 projectId, uint112 weight, uint256 weightCutMultiple, address caller);
```

