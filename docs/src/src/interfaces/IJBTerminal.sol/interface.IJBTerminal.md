# IJBTerminal
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBTerminal.sol)

**Inherits:**
IERC165

A terminal that accepts payments and can be migrated.


## Functions
### accountingContextForTokenOf


```solidity
function accountingContextForTokenOf(
    uint256 projectId,
    address token
)
    external
    view
    returns (JBAccountingContext memory);
```

### accountingContextsOf


```solidity
function accountingContextsOf(uint256 projectId) external view returns (JBAccountingContext[] memory);
```

### currentSurplusOf


```solidity
function currentSurplusOf(
    uint256 projectId,
    JBAccountingContext[] memory accountingContexts,
    uint256 decimals,
    uint256 currency
)
    external
    view
    returns (uint256);
```

### addAccountingContextsFor


```solidity
function addAccountingContextsFor(uint256 projectId, JBAccountingContext[] calldata accountingContexts) external;
```

### addToBalanceOf


```solidity
function addToBalanceOf(
    uint256 projectId,
    address token,
    uint256 amount,
    bool shouldReturnHeldFees,
    string calldata memo,
    bytes calldata metadata
)
    external
    payable;
```

### migrateBalanceOf


```solidity
function migrateBalanceOf(uint256 projectId, address token, IJBTerminal to) external returns (uint256 balance);
```

### pay


```solidity
function pay(
    uint256 projectId,
    address token,
    uint256 amount,
    address beneficiary,
    uint256 minReturnedTokens,
    string calldata memo,
    bytes calldata metadata
)
    external
    payable
    returns (uint256 beneficiaryTokenCount);
```

## Events
### AddToBalance

```solidity
event AddToBalance(
    uint256 indexed projectId, uint256 amount, uint256 returnedFees, string memo, bytes metadata, address caller
);
```

### HookAfterRecordPay

```solidity
event HookAfterRecordPay(
    IJBPayHook indexed hook, JBAfterPayRecordedContext context, uint256 specificationAmount, address caller
);
```

### MigrateTerminal

```solidity
event MigrateTerminal(
    uint256 indexed projectId, address indexed token, IJBTerminal indexed to, uint256 amount, address caller
);
```

### Pay

```solidity
event Pay(
    uint256 indexed rulesetId,
    uint256 indexed rulesetCycleNumber,
    uint256 indexed projectId,
    address payer,
    address beneficiary,
    uint256 amount,
    uint256 newlyIssuedTokenCount,
    string memo,
    bytes metadata,
    address caller
);
```

### SetAccountingContext

```solidity
event SetAccountingContext(uint256 indexed projectId, JBAccountingContext context, address caller);
```

