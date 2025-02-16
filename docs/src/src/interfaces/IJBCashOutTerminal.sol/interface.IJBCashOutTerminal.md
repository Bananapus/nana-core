# IJBCashOutTerminal
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBCashOutTerminal.sol)

**Inherits:**
[IJBTerminal](/src/interfaces/IJBTerminal.sol/interface.IJBTerminal.md)

A terminal that can be cashed out from.


## Functions
### cashOutTokensOf


```solidity
function cashOutTokensOf(
    address holder,
    uint256 projectId,
    uint256 cashOutCount,
    address tokenToReclaim,
    uint256 minTokensReclaimed,
    address payable beneficiary,
    bytes calldata metadata
)
    external
    returns (uint256 reclaimAmount);
```

## Events
### HookAfterRecordCashOut

```solidity
event HookAfterRecordCashOut(
    IJBCashOutHook indexed hook,
    JBAfterCashOutRecordedContext context,
    uint256 specificationAmount,
    uint256 fee,
    address caller
);
```

### CashOutTokens

```solidity
event CashOutTokens(
    uint256 indexed rulesetId,
    uint256 indexed rulesetCycleNumber,
    uint256 indexed projectId,
    address holder,
    address beneficiary,
    uint256 cashOutCount,
    uint256 cashOutTaxRate,
    uint256 reclaimAmount,
    bytes metadata,
    address caller
);
```

