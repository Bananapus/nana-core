# IJBTerminalStore
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBTerminalStore.sol)


## Functions
### DIRECTORY


```solidity
function DIRECTORY() external view returns (IJBDirectory);
```

### PRICES


```solidity
function PRICES() external view returns (IJBPrices);
```

### RULESETS


```solidity
function RULESETS() external view returns (IJBRulesets);
```

### balanceOf


```solidity
function balanceOf(address terminal, uint256 projectId, address token) external view returns (uint256);
```

### usedPayoutLimitOf


```solidity
function usedPayoutLimitOf(
    address terminal,
    uint256 projectId,
    address token,
    uint256 rulesetCycleNumber,
    uint256 currency
)
    external
    view
    returns (uint256);
```

### usedSurplusAllowanceOf


```solidity
function usedSurplusAllowanceOf(
    address terminal,
    uint256 projectId,
    address token,
    uint256 rulesetId,
    uint256 currency
)
    external
    view
    returns (uint256);
```

### currentReclaimableSurplusOf


```solidity
function currentReclaimableSurplusOf(
    uint256 projectId,
    uint256 tokenCount,
    uint256 totalSupply,
    uint256 surplus
)
    external
    view
    returns (uint256);
```

### currentReclaimableSurplusOf


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
    returns (uint256);
```

### currentSurplusOf


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
    returns (uint256);
```

### currentTotalSurplusOf


```solidity
function currentTotalSurplusOf(uint256 projectId, uint256 decimals, uint256 currency) external view returns (uint256);
```

### recordAddedBalanceFor


```solidity
function recordAddedBalanceFor(uint256 projectId, address token, uint256 amount) external;
```

### recordPaymentFrom


```solidity
function recordPaymentFrom(
    address payer,
    JBTokenAmount memory amount,
    uint256 projectId,
    address beneficiary,
    bytes calldata metadata
)
    external
    returns (JBRuleset memory ruleset, uint256 tokenCount, JBPayHookSpecification[] memory hookSpecifications);
```

### recordPayoutFor


```solidity
function recordPayoutFor(
    uint256 projectId,
    JBAccountingContext calldata accountingContext,
    uint256 amount,
    uint256 currency
)
    external
    returns (JBRuleset memory ruleset, uint256 amountPaidOut);
```

### recordCashOutFor


```solidity
function recordCashOutFor(
    address holder,
    uint256 projectId,
    uint256 cashOutCount,
    JBAccountingContext calldata accountingContext,
    JBAccountingContext[] calldata balanceAccountingContexts,
    bytes calldata metadata
)
    external
    returns (
        JBRuleset memory ruleset,
        uint256 reclaimAmount,
        uint256 cashOutTaxRate,
        JBCashOutHookSpecification[] memory hookSpecifications
    );
```

### recordTerminalMigration


```solidity
function recordTerminalMigration(uint256 projectId, address token) external returns (uint256 balance);
```

### recordUsedAllowanceOf


```solidity
function recordUsedAllowanceOf(
    uint256 projectId,
    JBAccountingContext calldata accountingContext,
    uint256 amount,
    uint256 currency
)
    external
    returns (JBRuleset memory ruleset, uint256 usedAmount);
```

