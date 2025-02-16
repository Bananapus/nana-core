# JBRulesetMetadataResolver
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/libraries/JBRulesetMetadataResolver.sol)


## Functions
### reservedPercent


```solidity
function reservedPercent(JBRuleset memory ruleset) internal pure returns (uint16);
```

### cashOutTaxRate


```solidity
function cashOutTaxRate(JBRuleset memory ruleset) internal pure returns (uint16);
```

### baseCurrency


```solidity
function baseCurrency(JBRuleset memory ruleset) internal pure returns (uint32);
```

### pausePay


```solidity
function pausePay(JBRuleset memory ruleset) internal pure returns (bool);
```

### pauseCreditTransfers


```solidity
function pauseCreditTransfers(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowOwnerMinting


```solidity
function allowOwnerMinting(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowSetCustomToken


```solidity
function allowSetCustomToken(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowTerminalMigration


```solidity
function allowTerminalMigration(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowSetTerminals


```solidity
function allowSetTerminals(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowSetController


```solidity
function allowSetController(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowAddAccountingContext


```solidity
function allowAddAccountingContext(JBRuleset memory ruleset) internal pure returns (bool);
```

### allowAddPriceFeed


```solidity
function allowAddPriceFeed(JBRuleset memory ruleset) internal pure returns (bool);
```

### ownerMustSendPayouts


```solidity
function ownerMustSendPayouts(JBRuleset memory ruleset) internal pure returns (bool);
```

### holdFees


```solidity
function holdFees(JBRuleset memory ruleset) internal pure returns (bool);
```

### useTotalSurplusForCashOuts


```solidity
function useTotalSurplusForCashOuts(JBRuleset memory ruleset) internal pure returns (bool);
```

### useDataHookForPay


```solidity
function useDataHookForPay(JBRuleset memory ruleset) internal pure returns (bool);
```

### useDataHookForCashOut


```solidity
function useDataHookForCashOut(JBRuleset memory ruleset) internal pure returns (bool);
```

### dataHook


```solidity
function dataHook(JBRuleset memory ruleset) internal pure returns (address);
```

### metadata


```solidity
function metadata(JBRuleset memory ruleset) internal pure returns (uint16);
```

### packRulesetMetadata

Pack the funding cycle metadata.


```solidity
function packRulesetMetadata(JBRulesetMetadata memory rulesetMetadata) internal pure returns (uint256 packed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rulesetMetadata`|`JBRulesetMetadata`|The ruleset metadata to validate and pack.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`packed`|`uint256`|The packed uint256 of all metadata params. The first 8 bits specify the version.|


### expandMetadata

Expand the funding cycle metadata.


```solidity
function expandMetadata(JBRuleset memory ruleset) internal pure returns (JBRulesetMetadata memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The funding cycle having its metadata expanded.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBRulesetMetadata`|rulesetMetadata The ruleset's metadata object.|


