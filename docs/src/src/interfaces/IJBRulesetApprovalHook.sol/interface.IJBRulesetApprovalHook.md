# IJBRulesetApprovalHook
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBRulesetApprovalHook.sol)

**Inherits:**
IERC165

`IJBRulesetApprovalHook`s are used to determine whether the next ruleset in the ruleset queue is approved or
rejected.

*Project rulesets are stored in a queue. Rulesets take effect after the previous ruleset in the queue ends, and
only if they are approved by the previous ruleset's approval hook.*


## Functions
### DURATION


```solidity
function DURATION() external view returns (uint256);
```

### approvalStatusOf


```solidity
function approvalStatusOf(
    uint256 projectId,
    uint256 rulesetId,
    uint256 start
)
    external
    view
    returns (JBApprovalStatus);
```

