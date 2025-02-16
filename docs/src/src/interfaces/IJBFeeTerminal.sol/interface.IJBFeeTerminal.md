# IJBFeeTerminal
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBFeeTerminal.sol)

**Inherits:**
[IJBTerminal](/src/interfaces/IJBTerminal.sol/interface.IJBTerminal.md)

A terminal that can process and hold fees.


## Functions
### FEE


```solidity
function FEE() external view returns (uint256);
```

### FEELESS_ADDRESSES


```solidity
function FEELESS_ADDRESSES() external view returns (IJBFeelessAddresses);
```

### heldFeesOf


```solidity
function heldFeesOf(uint256 projectId, address token, uint256 count) external view returns (JBFee[] memory);
```

### processHeldFeesOf


```solidity
function processHeldFeesOf(uint256 projectId, address token, uint256 count) external;
```

## Events
### FeeReverted

```solidity
event FeeReverted(
    uint256 indexed projectId,
    address indexed token,
    uint256 indexed feeProjectId,
    uint256 amount,
    bytes reason,
    address caller
);
```

### HoldFee

```solidity
event HoldFee(
    uint256 indexed projectId,
    address indexed token,
    uint256 indexed amount,
    uint256 fee,
    address beneficiary,
    address caller
);
```

### ProcessFee

```solidity
event ProcessFee(
    uint256 indexed projectId,
    address indexed token,
    uint256 indexed amount,
    bool wasHeld,
    address beneficiary,
    address caller
);
```

### ReturnHeldFees

```solidity
event ReturnHeldFees(
    uint256 indexed projectId,
    address indexed token,
    uint256 indexed amount,
    uint256 returnedFees,
    uint256 leftoverAmount,
    address caller
);
```

