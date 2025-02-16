# IJBPayHook
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBPayHook.sol)

**Inherits:**
IERC165

Hook called after a terminal's `pay(...)` logic completes (if passed by the ruleset's data hook).


## Functions
### afterPayRecordedWith

This function is called by the terminal's `pay(...)` function after the payment has been recorded in the
terminal store.

*Critical business logic should be protected by appropriate access control.*


```solidity
function afterPayRecordedWith(JBAfterPayRecordedContext calldata context) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`context`|`JBAfterPayRecordedContext`|The context passed in by the terminal, as a `JBAfterPayRecordedContext` struct.|


