# IJBSplitHook
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBSplitHook.sol)

**Inherits:**
IERC165

Allows processing a single split with custom logic.

*The split hook's address should be set as the `hook` in the relevant split.*


## Functions
### processSplitWith

If a split has a split hook, payment terminals and controllers call this function while processing the
split.

*Critical business logic should be protected by appropriate access control. The tokens and/or native tokens
are optimistically transferred to the split hook when this function is called.*


```solidity
function processSplitWith(JBSplitHookContext calldata context) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`context`|`JBSplitHookContext`|The context passed by the terminal/controller to the split hook as a `JBSplitHookContext` struct:|


