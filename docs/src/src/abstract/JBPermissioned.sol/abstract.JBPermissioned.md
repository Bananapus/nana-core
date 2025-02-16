# JBPermissioned
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/abstract/JBPermissioned.sol)

**Inherits:**
Context, [IJBPermissioned](/src/interfaces/IJBPermissioned.sol/interface.IJBPermissioned.md)

Modifiers to allow access to transactions based on which permissions the message's sender has.


## State Variables
### PERMISSIONS
A contract storing permissions.


```solidity
IJBPermissions public immutable override PERMISSIONS;
```


## Functions
### constructor


```solidity
constructor(IJBPermissions permissions);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permissions`|`IJBPermissions`|A contract storing permissions.|


### _requirePermissionFrom

Require the message sender to be the account or have the relevant permission.


```solidity
function _requirePermissionFrom(address account, uint256 projectId, uint256 permissionId) internal view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to allow.|
|`projectId`|`uint256`|The project ID to check the permission under.|
|`permissionId`|`uint256`|The required permission ID. The operator must have this permission within the specified project ID.|


### _requirePermissionAllowingOverrideFrom

If the 'alsoGrantAccessIf' condition is truthy, proceed. Otherwise, require the message sender to be the
account or
have the relevant permission.


```solidity
function _requirePermissionAllowingOverrideFrom(
    address account,
    uint256 projectId,
    uint256 permissionId,
    bool alsoGrantAccessIf
)
    internal
    view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to allow.|
|`projectId`|`uint256`|The project ID to check the permission under.|
|`permissionId`|`uint256`|The required permission ID. The operator must have this permission within the specified project ID.|
|`alsoGrantAccessIf`|`bool`|An override condition which will allow access regardless of permissions.|


## Errors
### JBPermissioned_Unauthorized

```solidity
error JBPermissioned_Unauthorized(address account, address sender, uint256 projectId, uint256 permissionId);
```

