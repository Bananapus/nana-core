# IJBFeelessAddresses
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBFeelessAddresses.sol)


## Functions
### isFeeless


```solidity
function isFeeless(address account) external view returns (bool);
```

### setFeelessAddress


```solidity
function setFeelessAddress(address account, bool flag) external;
```

## Events
### SetFeelessAddress

```solidity
event SetFeelessAddress(address indexed addr, bool indexed isFeeless, address caller);
```

