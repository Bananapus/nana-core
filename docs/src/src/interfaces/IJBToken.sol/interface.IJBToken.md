# IJBToken
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBToken.sol)


## Functions
### balanceOf


```solidity
function balanceOf(address account) external view returns (uint256);
```

### canBeAddedTo


```solidity
function canBeAddedTo(uint256 projectId) external view returns (bool);
```

### decimals


```solidity
function decimals() external view returns (uint8);
```

### totalSupply


```solidity
function totalSupply() external view returns (uint256);
```

### initialize


```solidity
function initialize(string memory name, string memory symbol, address owner) external;
```

### burn


```solidity
function burn(address account, uint256 amount) external;
```

### mint


```solidity
function mint(address account, uint256 amount) external;
```

