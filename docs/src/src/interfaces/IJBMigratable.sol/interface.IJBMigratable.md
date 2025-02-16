# IJBMigratable
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBMigratable.sol)

**Inherits:**
IERC165


## Functions
### migrate


```solidity
function migrate(uint256 projectId, IERC165 to) external;
```

### beforeReceiveMigrationFrom


```solidity
function beforeReceiveMigrationFrom(IERC165 from, uint256 projectId) external;
```

## Events
### Migrate

```solidity
event Migrate(uint256 indexed projectId, IERC165 to, address caller);
```

