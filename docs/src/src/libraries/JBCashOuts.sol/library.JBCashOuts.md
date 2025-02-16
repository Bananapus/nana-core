# JBCashOuts
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/libraries/JBCashOuts.sol)

Cash out calculations.


## Functions
### cashOutFrom

Returns the amount of surplus terminal tokens which can be reclaimed based on the total surplus, the
number of tokens being cashed out, the total token supply, and the ruleset's cash out tax rate.


```solidity
function cashOutFrom(
    uint256 surplus,
    uint256 cashOutCount,
    uint256 totalSupply,
    uint256 cashOutTaxRate
)
    internal
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`surplus`|`uint256`|The total amount of surplus terminal tokens.|
|`cashOutCount`|`uint256`|The number of tokens being cashed out, as a fixed point number with 18 decimals.|
|`totalSupply`|`uint256`|The total token supply, as a fixed point number with 18 decimals.|
|`cashOutTaxRate`|`uint256`|The current ruleset's cash out tax rate.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|reclaimableSurplus The amount of surplus tokens that can be reclaimed.|


