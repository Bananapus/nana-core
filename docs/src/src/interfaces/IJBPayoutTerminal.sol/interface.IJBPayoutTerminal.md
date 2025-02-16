# IJBPayoutTerminal
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBPayoutTerminal.sol)

**Inherits:**
[IJBTerminal](/src/interfaces/IJBTerminal.sol/interface.IJBTerminal.md)

A terminal that can send payouts.


## Functions
### sendPayoutsOf


```solidity
function sendPayoutsOf(
    uint256 projectId,
    address token,
    uint256 amount,
    uint256 currency,
    uint256 minTokensPaidOut
)
    external
    returns (uint256 netLeftoverPayoutAmount);
```

### useAllowanceOf


```solidity
function useAllowanceOf(
    uint256 projectId,
    address token,
    uint256 amount,
    uint256 currency,
    uint256 minTokensPaidOut,
    address payable beneficiary,
    address payable feeBeneficiary,
    string calldata memo
)
    external
    returns (uint256 netAmountPaidOut);
```

## Events
### PayoutReverted

```solidity
event PayoutReverted(uint256 indexed projectId, JBSplit split, uint256 amount, bytes reason, address caller);
```

### PayoutTransferReverted

```solidity
event PayoutTransferReverted(
    uint256 indexed projectId, address addr, address token, uint256 amount, uint256 fee, bytes reason, address caller
);
```

### SendPayouts

```solidity
event SendPayouts(
    uint256 indexed rulesetId,
    uint256 indexed rulesetCycleNumber,
    uint256 indexed projectId,
    address projectOwner,
    uint256 amount,
    uint256 amountPaidOut,
    uint256 fee,
    uint256 netLeftoverPayoutAmount,
    address caller
);
```

### SendPayoutToSplit

```solidity
event SendPayoutToSplit(
    uint256 indexed projectId,
    uint256 indexed rulesetId,
    uint256 indexed group,
    JBSplit split,
    uint256 amount,
    uint256 netAmount,
    address caller
);
```

### UseAllowance

```solidity
event UseAllowance(
    uint256 indexed rulesetId,
    uint256 indexed rulesetCycleNumber,
    uint256 indexed projectId,
    address beneficiary,
    address feeBeneficiary,
    uint256 amount,
    uint256 amountPaidOut,
    uint256 netAmountPaidOut,
    string memo,
    address caller
);
```

