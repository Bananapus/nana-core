# IJBCashOutHook
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBCashOutHook.sol)

**Inherits:**
IERC165

Hook called after a terminal's `cashOutTokensOf(...)` logic completes (if passed by the ruleset's data
hook).


## Functions
### afterCashOutRecordedWith

This function is called by the terminal's `cashOutTokensOf(...)` function after the cash out has been
recorded in the terminal store.

*Critical business logic should be protected by appropriate access control.*


```solidity
function afterCashOutRecordedWith(JBAfterCashOutRecordedContext calldata context) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`context`|`JBAfterCashOutRecordedContext`|The context passed in by the terminal, as a `JBAfterCashOutRecordedContext` struct.|


