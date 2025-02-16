# JBFees
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/libraries/JBFees.sol)

Fee calculations.


## Functions
### feeAmountResultingIn

Returns the amount of tokens to pay as a fee relative to the specified `amount`.


```solidity
function feeAmountResultingIn(uint256 amountAfterFee, uint256 feePercent) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountAfterFee`|`uint256`|The amount that the fee is based on, as a fixed point number.|
|`feePercent`|`uint256`|The fee percent, out of `JBConstants.MAX_FEE`.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of tokens to pay as a fee, as a fixed point number with the same number of decimals as the provided `amount`.|


### feeAmountFrom

Returns the fee that would have been paid based on an `amount` which has already had the fee subtracted
from it.


```solidity
function feeAmountFrom(uint256 amountBeforeFee, uint256 feePercent) internal pure returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amountBeforeFee`|`uint256`|The amount that the fee is based on, as a fixed point number with the same amount of decimals as this terminal.|
|`feePercent`|`uint256`|The fee percent, out of `JBConstants.MAX_FEE`.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of the fee, as a fixed point number with the same amount of decimals as this terminal.|


