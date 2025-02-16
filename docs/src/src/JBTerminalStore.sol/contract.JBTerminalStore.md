# JBTerminalStore
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBTerminalStore.sol)

**Inherits:**
[IJBTerminalStore](/src/interfaces/IJBTerminalStore.sol/interface.IJBTerminalStore.md)

Manages all bookkeeping for inflows and outflows of funds from any terminal address.

*This contract expects a project's controller to be an `IJBController`.*


## State Variables
### _MAX_FIXED_POINT_FIDELITY
Constrains `mulDiv` operations on fixed point numbers to a maximum number of decimal points of persisted
fidelity.


```solidity
uint256 internal constant _MAX_FIXED_POINT_FIDELITY = 18;
```


### DIRECTORY
The directory of terminals and controllers for projects.


```solidity
IJBDirectory public immutable override DIRECTORY;
```


### PRICES
The contract that exposes price feeds.


```solidity
IJBPrices public immutable override PRICES;
```


### RULESETS
The contract storing and managing project rulesets.


```solidity
IJBRulesets public immutable override RULESETS;
```


### balanceOf
A project's balance of a specific token within a terminal.

*The balance is represented as a fixed point number with the same amount of decimals as its relative
terminal.*


```solidity
mapping(address terminal => mapping(uint256 projectId => mapping(address token => uint256))) public override balanceOf;
```


### usedPayoutLimitOf
The currency-denominated amount of funds that a project has already paid out from its payout limit
during the current ruleset for each terminal, in terms of the payout limit's currency.

*Increases as projects pay out funds.*

*The used payout limit is represented as a fixed point number with the same amount of decimals as the
terminal it applies to.*


```solidity
mapping(
    address terminal
        => mapping(
            uint256 projectId
                => mapping(address token => mapping(uint256 rulesetCycleNumber => mapping(uint256 currency => uint256)))
        )
) public override usedPayoutLimitOf;
```


### usedSurplusAllowanceOf
The currency-denominated amounts of funds that a project has used from its surplus allowance during the
current ruleset for each terminal, in terms of the surplus allowance's currency.

*Increases as projects use their allowance.*

*The used surplus allowance is represented as a fixed point number with the same amount of decimals as the
terminal it applies to.*


```solidity
mapping(
    address terminal
        => mapping(
            uint256 projectId
                => mapping(address token => mapping(uint256 rulesetId => mapping(uint256 currency => uint256)))
        )
) public override usedSurplusAllowanceOf;
```


## Functions
### constructor


```solidity
constructor(IJBDirectory directory, IJBPrices prices, IJBRulesets rulesets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing directories of terminals and controllers for each project.|
|`prices`|`IJBPrices`|A contract that exposes price feeds.|
|`rulesets`|`IJBRulesets`|A contract storing and managing project rulesets.|


### currentReclaimableSurplusOf

Returns the number of surplus terminal tokens that would be reclaimed by cashing out a given project's
tokens based on its current ruleset and the given total project token supply and total terminal token surplus.


```solidity
function currentReclaimableSurplusOf(
    uint256 projectId,
    uint256 cashOutCount,
    uint256 totalSupply,
    uint256 surplus
)
    external
    view
    override
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose project tokens would be cashed out.|
|`cashOutCount`|`uint256`|The number of project tokens that would be cashed out, as a fixed point number with 18 decimals.|
|`totalSupply`|`uint256`|The total project token supply, as a fixed point number with 18 decimals.|
|`surplus`|`uint256`|The total terminal token surplus amount, as a fixed point number.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of surplus terminal tokens that would be reclaimed, as a fixed point number with the same number of decimals as the provided `surplus`.|


### currentReclaimableSurplusOf

Returns the number of surplus terminal tokens that would be reclaimed from a terminal by cashing out a
given number of tokens, based on the total token supply and total surplus.

*The returned amount in terms of the specified `terminal`'s base currency.*

*The returned amount is represented as a fixed point number with the same amount of decimals as the
specified terminal.*


```solidity
function currentReclaimableSurplusOf(
    uint256 projectId,
    uint256 cashOutCount,
    IJBTerminal[] calldata terminals,
    JBAccountingContext[] calldata accountingContexts,
    uint256 decimals,
    uint256 currency
)
    external
    view
    override
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose tokens would be cashed out.|
|`cashOutCount`|`uint256`|The number of tokens that would be cashed out, as a fixed point number with 18 decimals.|
|`terminals`|`IJBTerminal[]`|The terminals that would be cashed out from. If this is an empty array, surplus within all the project's terminals are considered.|
|`accountingContexts`|`JBAccountingContext[]`|The accounting contexts of the surplus terminal tokens that would be reclaimed. Pass an empty array to use all of the project's accounting contexts.|
|`decimals`|`uint256`|The number of decimals to include in the resulting fixed point number.|
|`currency`|`uint256`|The currency that the resulting number will be in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of surplus terminal tokens that would be reclaimed by cashing out `cashOutCount` tokens.|


### currentSurplusOf

Gets the current surplus amount in a terminal for a specified project.

*The surplus is the amount of funds a project has in a terminal in excess of its payout limit.*

*The surplus is represented as a fixed point number with the same amount of decimals as the specified
terminal.*


```solidity
function currentSurplusOf(
    address terminal,
    uint256 projectId,
    JBAccountingContext[] calldata accountingContexts,
    uint256 decimals,
    uint256 currency
)
    external
    view
    override
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`terminal`|`address`|The terminal the surplus is being calculated for.|
|`projectId`|`uint256`|The ID of the project to get surplus for.|
|`accountingContexts`|`JBAccountingContext[]`|The accounting contexts of tokens whose balances should contribute to the surplus being calculated.|
|`decimals`|`uint256`|The number of decimals to expect in the resulting fixed point number.|
|`currency`|`uint256`|The currency the resulting amount should be in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current surplus amount the project has in the specified terminal.|


### currentTotalSurplusOf

Gets the current surplus amount for a specified project across all terminals.


```solidity
function currentTotalSurplusOf(
    uint256 projectId,
    uint256 decimals,
    uint256 currency
)
    external
    view
    override
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the total surplus for.|
|`decimals`|`uint256`|The number of decimals that the fixed point surplus should include.|
|`currency`|`uint256`|The currency that the total surplus should be in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current total surplus amount that the project has across all terminals.|


### _surplusFrom

Gets a project's surplus amount in a terminal as measured by a given ruleset, across multiple accounting
contexts.

*This amount changes as the value of the balance changes in relation to the currency being used to measure
various payout limits.*


```solidity
function _surplusFrom(
    address terminal,
    uint256 projectId,
    JBAccountingContext[] memory accountingContexts,
    JBRuleset memory ruleset,
    uint256 targetDecimals,
    uint256 targetCurrency
)
    internal
    view
    returns (uint256 surplus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`terminal`|`address`|The terminal the surplus is being calculated for.|
|`projectId`|`uint256`|The ID of the project to get the surplus for.|
|`accountingContexts`|`JBAccountingContext[]`|The accounting contexts of tokens whose balances should contribute to the surplus being calculated.|
|`ruleset`|`JBRuleset`|The ID of the ruleset to base the surplus on.|
|`targetDecimals`|`uint256`|The number of decimals to include in the resulting fixed point number.|
|`targetCurrency`|`uint256`|The currency that the reported surplus is expected to be in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`surplus`|`uint256`|The surplus of funds in terms of `targetCurrency`, as a fixed point number with `targetDecimals` decimals.|


### _tokenSurplusFrom

Get a project's surplus amount of a specific token in a given terminal as measured by a given ruleset
(one specific accounting context).

*This amount changes as the value of the balance changes in relation to the currency being used to measure
the payout limits.*


```solidity
function _tokenSurplusFrom(
    address terminal,
    uint256 projectId,
    JBAccountingContext memory accountingContext,
    JBRuleset memory ruleset,
    uint256 targetDecimals,
    uint256 targetCurrency
)
    internal
    view
    returns (uint256 surplus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`terminal`|`address`|The terminal the surplus is being calculated for.|
|`projectId`|`uint256`|The ID of the project to get the surplus of.|
|`accountingContext`|`JBAccountingContext`|The accounting context of the token whose balance should contribute to the surplus being measured.|
|`ruleset`|`JBRuleset`|The ID of the ruleset to base the surplus calculation on.|
|`targetDecimals`|`uint256`|The number of decimals to include in the resulting fixed point number.|
|`targetCurrency`|`uint256`|The currency that the reported surplus is expected to be in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`surplus`|`uint256`|The surplus of funds in terms of `targetCurrency`, as a fixed point number with `targetDecimals` decimals.|


### recordAddedBalanceFor

Records funds being added to a project's balance.


```solidity
function recordAddedBalanceFor(uint256 projectId, address token, uint256 amount) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project which funds are being added to the balance of.|
|`token`|`address`|The token being added to the balance.|
|`amount`|`uint256`|The amount of terminal tokens added, as a fixed point number with the same amount of decimals as its relative terminal.|


### recordCashOutFor

Records a cash out from a project.

*Cashs out the project's tokens according to values provided by the ruleset's data hook. If the ruleset has
no
data hook, cashs out tokens along a cash out bonding curve that is a function of the number of tokens being
burned.*


```solidity
function recordCashOutFor(
    address holder,
    uint256 projectId,
    uint256 cashOutCount,
    JBAccountingContext calldata accountingContext,
    JBAccountingContext[] calldata balanceAccountingContexts,
    bytes memory metadata
)
    external
    override
    returns (
        JBRuleset memory ruleset,
        uint256 reclaimAmount,
        uint256 cashOutTaxRate,
        JBCashOutHookSpecification[] memory hookSpecifications
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The account that is cashing out tokens.|
|`projectId`|`uint256`|The ID of the project being cashing out from.|
|`cashOutCount`|`uint256`|The number of project tokens to cash out, as a fixed point number with 18 decimals.|
|`accountingContext`|`JBAccountingContext`|The accounting context of the token being reclaimed by the cash out.|
|`balanceAccountingContexts`|`JBAccountingContext[]`|The accounting contexts of the tokens whose balances should contribute to the surplus being reclaimed from.|
|`metadata`|`bytes`|Bytes to send to the data hook, if the project's current ruleset specifies one.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The ruleset during the cash out was made during, as a `JBRuleset` struct. This ruleset will have a cash out tax rate provided by the cash out hook if applicable.|
|`reclaimAmount`|`uint256`|The amount of tokens reclaimed from the terminal, as a fixed point number with 18 decimals.|
|`cashOutTaxRate`|`uint256`|The cash out tax rate influencing the reclaim amount.|
|`hookSpecifications`|`JBCashOutHookSpecification[]`|A list of cash out hooks, including data and amounts to send to them. The terminal should fulfill these specifications.|


### recordPaymentFrom

Records a payment to a project.

*Mints the project's tokens according to values provided by the ruleset's data hook. If the ruleset has no
data hook, mints tokens in proportion with the amount paid.*


```solidity
function recordPaymentFrom(
    address payer,
    JBTokenAmount calldata amount,
    uint256 projectId,
    address beneficiary,
    bytes calldata metadata
)
    external
    override
    returns (JBRuleset memory ruleset, uint256 tokenCount, JBPayHookSpecification[] memory hookSpecifications);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`payer`|`address`|The address that made the payment to the terminal.|
|`amount`|`JBTokenAmount`|The amount of tokens being paid. Includes the token being paid, their value, the number of decimals included, and the currency of the amount.|
|`projectId`|`uint256`|The ID of the project being paid.|
|`beneficiary`|`address`|The address that should be the beneficiary of anything the payment yields (including project tokens minted by the payment).|
|`metadata`|`bytes`|Bytes to send to the data hook, if the project's current ruleset specifies one.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The ruleset the payment was made during, as a `JBRuleset` struct.|
|`tokenCount`|`uint256`|The number of project tokens that were minted, as a fixed point number with 18 decimals.|
|`hookSpecifications`|`JBPayHookSpecification[]`|A list of pay hooks, including data and amounts to send to them. The terminal should fulfill these specifications.|


### recordPayoutFor

Records a payout from a project.


```solidity
function recordPayoutFor(
    uint256 projectId,
    JBAccountingContext calldata accountingContext,
    uint256 amount,
    uint256 currency
)
    external
    override
    returns (JBRuleset memory ruleset, uint256 amountPaidOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project that is paying out funds.|
|`accountingContext`|`JBAccountingContext`|The context of the token being paid out.|
|`amount`|`uint256`|The amount to pay out (use from the payout limit), as a fixed point number.|
|`currency`|`uint256`|The currency of the `amount`. This must match the project's current ruleset's currency.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The ruleset the payout was made during, as a `JBRuleset` struct.|
|`amountPaidOut`|`uint256`|The amount of terminal tokens paid out, as a fixed point number with the same amount of decimals as its relative terminal.|


### recordTerminalMigration

Records the migration of funds from this store.


```solidity
function recordTerminalMigration(uint256 projectId, address token) external override returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project being migrated.|
|`token`|`address`|The token being migrated.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The project's current balance (which is being migrated), as a fixed point number with the same amount of decimals as its relative terminal.|


### recordUsedAllowanceOf

Records a use of a project's surplus allowance.

*When surplus allowance is "used", it is taken out of the project's surplus within a terminal.*


```solidity
function recordUsedAllowanceOf(
    uint256 projectId,
    JBAccountingContext calldata accountingContext,
    uint256 amount,
    uint256 currency
)
    external
    override
    returns (JBRuleset memory ruleset, uint256 usedAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to use the surplus allowance of.|
|`accountingContext`|`JBAccountingContext`|The accounting context of the token whose balances should contribute to the surplus allowance being reclaimed from.|
|`amount`|`uint256`|The amount to use from the surplus allowance, as a fixed point number.|
|`currency`|`uint256`|The currency of the `amount`. Must match the currency of the surplus allowance.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The ruleset during the surplus allowance is being used during, as a `JBRuleset` struct.|
|`usedAmount`|`uint256`|The amount of terminal tokens used, as a fixed point number with the same amount of decimals as its relative terminal.|


## Errors
### JBTerminalStore_InadequateControllerAllowance

```solidity
error JBTerminalStore_InadequateControllerAllowance(uint256 amount, uint256 allowance);
```

### JBTerminalStore_InadequateControllerPayoutLimit

```solidity
error JBTerminalStore_InadequateControllerPayoutLimit(uint256 amount, uint256 limit);
```

### JBTerminalStore_InadequateTerminalStoreBalance

```solidity
error JBTerminalStore_InadequateTerminalStoreBalance(uint256 amount, uint256 balance);
```

### JBTerminalStore_InsufficientTokens

```solidity
error JBTerminalStore_InsufficientTokens(uint256 count, uint256 totalSupply);
```

### JBTerminalStore_InvalidAmountToForwardHook

```solidity
error JBTerminalStore_InvalidAmountToForwardHook(uint256 amount, uint256 paidAmount);
```

### JBTerminalStore_RulesetNotFound

```solidity
error JBTerminalStore_RulesetNotFound();
```

### JBTerminalStore_RulesetPaymentPaused

```solidity
error JBTerminalStore_RulesetPaymentPaused();
```

### JBTerminalStore_TerminalMigrationNotAllowed

```solidity
error JBTerminalStore_TerminalMigrationNotAllowed();
```

