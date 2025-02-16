# IJBRulesetDataHook
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBRulesetDataHook.sol)

**Inherits:**
IERC165

Data hooks can extend a terminal's core pay/cashout functionality by overriding the weight or memo. They can
also specify pay/cashout hooks for the terminal to fulfill, or allow addresses to mint a project's tokens on-demand.

*If a project's ruleset has `useDataHookForPay` or `useDataHookForCashOut` enabled, its `dataHook` is called by
the terminal upon payments/cashouts (respectively).*


## Functions
### hasMintPermissionFor

A flag indicating whether an address has permission to mint a project's tokens on-demand.

*A project's data hook can allow any address to mint its tokens.*


```solidity
function hasMintPermissionFor(uint256 projectId, address addr) external view returns (bool flag);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose token can be minted.|
|`addr`|`address`|The address to check the token minting permission of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`flag`|`bool`|A flag indicating whether the address has permission to mint the project's tokens on-demand.|


### beforePayRecordedWith

The data calculated before a payment is recorded in the terminal store. This data is provided to the
terminal's `pay(...)` transaction.


```solidity
function beforePayRecordedWith(JBBeforePayRecordedContext calldata context)
    external
    view
    returns (uint256 weight, JBPayHookSpecification[] memory hookSpecifications);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`context`|`JBBeforePayRecordedContext`|The context passed to this data hook by the `pay(...)` function as a `JBBeforePayRecordedContext` struct.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`weight`|`uint256`|The new `weight` to use, overriding the ruleset's `weight`.|
|`hookSpecifications`|`JBPayHookSpecification[]`|The amount and data to send to pay hooks instead of adding to the terminal's balance.|


### beforeCashOutRecordedWith

The data calculated before a cash out is recorded in the terminal store. This data is provided to the
terminal's `cashOutTokensOf(...)` transaction.


```solidity
function beforeCashOutRecordedWith(JBBeforeCashOutRecordedContext calldata context)
    external
    view
    returns (
        uint256 cashOutTaxRate,
        uint256 cashOutCount,
        uint256 totalSupply,
        JBCashOutHookSpecification[] memory hookSpecifications
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`context`|`JBBeforeCashOutRecordedContext`|The context passed to this data hook by the `cashOutTokensOf(...)` function as a `JBBeforeCashOutRecordedContext` struct.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`cashOutTaxRate`|`uint256`|The rate determining the amount that should be reclaimable for a given surplus and token supply.|
|`cashOutCount`|`uint256`|The amount of tokens that should be considered cashed out.|
|`totalSupply`|`uint256`|The total amount of tokens that are considered to be existing.|
|`hookSpecifications`|`JBCashOutHookSpecification[]`|The amount and data to send to cash out hooks instead of returning to the beneficiary.|


