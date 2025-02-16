# JBSurplus
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/libraries/JBSurplus.sol)

Surplus calculations.


## Functions
### currentSurplusOf

Gets the total current surplus amount across all of a project's terminals.

*This amount changes as the value of the balances changes in relation to the currency being used to measure
the project's payout limits.*


```solidity
function currentSurplusOf(
    uint256 projectId,
    IJBTerminal[] memory terminals,
    JBAccountingContext[] memory accountingContexts,
    uint256 decimals,
    uint256 currency
)
    internal
    view
    returns (uint256 surplus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the total surplus for.|
|`terminals`|`IJBTerminal[]`|The terminals to look for surplus within.|
|`accountingContexts`|`JBAccountingContext[]`|The accounting contexts to use to calculate the surplus.|
|`decimals`|`uint256`|The number of decimals that the fixed point surplus result should include.|
|`currency`|`uint256`|The currency that the surplus result should be in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`surplus`|`uint256`|The total surplus of a project's funds in terms of `currency`, as a fixed point number with the specified number of decimals.|


