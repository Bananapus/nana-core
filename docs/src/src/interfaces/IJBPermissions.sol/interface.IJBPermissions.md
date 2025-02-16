# IJBPermissions
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBPermissions.sol)


## Functions
### WILDCARD_PROJECT_ID


```solidity
function WILDCARD_PROJECT_ID() external view returns (uint256);
```

### permissionsOf


```solidity
function permissionsOf(address operator, address account, uint256 projectId) external view returns (uint256);
```

### hasPermission


```solidity
function hasPermission(
    address operator,
    address account,
    uint256 projectId,
    uint256 permissionId,
    bool includeRoot,
    bool includeWildcardProjectId
)
    external
    view
    returns (bool);
```

### hasPermissions


```solidity
function hasPermissions(
    address operator,
    address account,
    uint256 projectId,
    uint256[] calldata permissionIds,
    bool includeRoot,
    bool includeWildcardProjectId
)
    external
    view
    returns (bool);
```

### setPermissionsFor


```solidity
function setPermissionsFor(address account, JBPermissionsData calldata permissionsData) external;
```

## Events
### OperatorPermissionsSet

```solidity
event OperatorPermissionsSet(
    address indexed operator,
    address indexed account,
    uint256 indexed projectId,
    uint8[] permissionIds,
    uint256 packed,
    address caller
);
```

