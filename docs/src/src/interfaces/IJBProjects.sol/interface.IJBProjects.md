# IJBProjects
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBProjects.sol)

**Inherits:**
IERC721


## Functions
### count


```solidity
function count() external view returns (uint256);
```

### tokenUriResolver


```solidity
function tokenUriResolver() external view returns (IJBTokenUriResolver);
```

### createFor


```solidity
function createFor(address owner) external returns (uint256 projectId);
```

### setTokenUriResolver


```solidity
function setTokenUriResolver(IJBTokenUriResolver resolver) external;
```

## Events
### Create

```solidity
event Create(uint256 indexed projectId, address indexed owner, address caller);
```

### SetTokenUriResolver

```solidity
event SetTokenUriResolver(IJBTokenUriResolver indexed resolver, address caller);
```

