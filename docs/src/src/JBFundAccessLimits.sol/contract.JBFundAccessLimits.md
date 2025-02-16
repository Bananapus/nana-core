# JBFundAccessLimits
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBFundAccessLimits.sol)

**Inherits:**
[JBControlled](/src/abstract/JBControlled.sol/abstract.JBControlled.md), [IJBFundAccessLimits](/src/interfaces/IJBFundAccessLimits.sol/interface.IJBFundAccessLimits.md)

Stores and manages terminal fund access limits for each project.

*See the `JBFundAccessLimitGroup` struct to learn about payout limits and surplus allowances.*


## State Variables
### _packedPayoutLimitsDataOf
An array of packed payout limits for a given project, ruleset, terminal, and token.

*bits 0-223: The maximum amount (in a specific currency) of the terminal's `token`s that the project can pay
out during the ruleset.*

*bits 224-255: The currency that the payout limit is denominated in. If this currency is different from the
terminal's `token`, the payout limit will vary depending on their exchange rate.*


```solidity
mapping(
    uint256 projectId => mapping(uint256 rulesetId => mapping(address terminal => mapping(address token => uint256[])))
) internal _packedPayoutLimitsDataOf;
```


### _packedSurplusAllowancesDataOf
An array of packed surplus allowances for a given project, ruleset, terminal, and token.

*bits 0-223: The maximum amount (in a specific currency) of the terminal's `token`s that the project can
access from its surplus during the ruleset.*

*bits 224-255: The currency that the surplus allowance is denominated in. If this currency is different from
the terminal's `token`, the surplus allowance will vary depending on their exchange rate.*


```solidity
mapping(
    uint256 projectId => mapping(uint256 rulesetId => mapping(address terminal => mapping(address token => uint256[])))
) internal _packedSurplusAllowancesDataOf;
```


## Functions
### constructor


```solidity
constructor(IJBDirectory directory) JBControlled(directory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing the terminals and the controller used by each project.|


### payoutLimitOf

A project's payout limit for a given ruleset, terminal, token, and currency.

*The fixed point return amount will use the same number of decimals as the `terminal`.*


```solidity
function payoutLimitOf(
    uint256 projectId,
    uint256 rulesetId,
    address terminal,
    address token,
    uint256 currency
)
    external
    view
    override
    returns (uint256 payoutLimit);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The project's ID.|
|`rulesetId`|`uint256`|The ruleset's ID.|
|`terminal`|`address`|The terminal the payout limit applies to.|
|`token`|`address`|The token the payout limit applies to.|
|`currency`|`uint256`|The currency the payout limit is denominated in.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`payoutLimit`|`uint256`|The payout limit, as a fixed point number with the same number of decimals as the provided terminal.|


### payoutLimitsOf

A project's payout limits for a given ruleset, terminal, and token.

The total value of `token`s that a project can pay out from the terminal during the ruleset is dictated
by a list of payout limits. Each payout limit is a fixed-point amount in terms of a currency.

*The fixed point `amount`s returned will use the same number of decimals as the `terminal`.*


```solidity
function payoutLimitsOf(
    uint256 projectId,
    uint256 rulesetId,
    address terminal,
    address token
)
    external
    view
    override
    returns (JBCurrencyAmount[] memory payoutLimits);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The project's ID.|
|`rulesetId`|`uint256`|The ruleset's ID.|
|`terminal`|`address`|The terminal the payout limits apply to.|
|`token`|`address`|The token the payout limits apply to.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`payoutLimits`|`JBCurrencyAmount[]`|The payout limits.|


### surplusAllowanceOf

A project's surplus allowance for a given ruleset, terminal, token, and currency.

*The fixed point return amount will use the same number of decimals as the `terminal`.*


```solidity
function surplusAllowanceOf(
    uint256 projectId,
    uint256 rulesetId,
    address terminal,
    address token,
    uint256 currency
)
    external
    view
    override
    returns (uint256 surplusAllowance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The project's ID.|
|`rulesetId`|`uint256`|The ruleset's ID.|
|`terminal`|`address`|The terminal the surplus allowance applies to.|
|`token`|`address`|The token the surplus allowance applies to.|
|`currency`|`uint256`|The currency that the surplus allowance is denominated in.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`surplusAllowance`|`uint256`|The surplus allowance, as a fixed point number with the same number of decimals as the provided terminal.|


### surplusAllowancesOf

A project's surplus allowances for a given ruleset, terminal, and token.

The total value of `token`s that a project can pay out from its surplus in a terminal during the ruleset
is dictated by a list of surplus allowances. Each surplus allowance is a fixed-point amount in terms of a
currency.

*The fixed point `amount`s returned will use the same number of decimals as the `terminal`.*


```solidity
function surplusAllowancesOf(
    uint256 projectId,
    uint256 rulesetId,
    address terminal,
    address token
)
    external
    view
    override
    returns (JBCurrencyAmount[] memory surplusAllowances);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The project's ID.|
|`rulesetId`|`uint256`|The ruleset's ID.|
|`terminal`|`address`|The terminal the surplus allowances apply to.|
|`token`|`address`|The token the surplus allowances apply to.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`surplusAllowances`|`JBCurrencyAmount[]`|The surplus allowances.|


### setFundAccessLimitsFor

Sets limits on the amount of funds a project can access from its terminals during a ruleset.

*Only a project's controller can set its fund access limits.*

*Payout limits and surplus allowances must be specified in strictly increasing order (by currency) to
prevent duplicates.*


```solidity
function setFundAccessLimitsFor(
    uint256 projectId,
    uint256 rulesetId,
    JBFundAccessLimitGroup[] calldata fundAccessLimitGroups
)
    external
    override
    onlyControllerOf(projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose fund access limits are being set.|
|`rulesetId`|`uint256`|The ID of the ruleset that the limits will apply within.|
|`fundAccessLimitGroups`|`JBFundAccessLimitGroup[]`|An array containing payout limits and surplus allowances for each payment terminal. Amounts are fixed point numbers using the same number of decimals as the associated terminal.|


## Errors
### JBFundAccessLimits_InvalidPayoutLimitCurrencyOrdering

```solidity
error JBFundAccessLimits_InvalidPayoutLimitCurrencyOrdering();
```

### JBFundAccessLimits_InvalidSurplusAllowanceCurrencyOrdering

```solidity
error JBFundAccessLimits_InvalidSurplusAllowanceCurrencyOrdering();
```

