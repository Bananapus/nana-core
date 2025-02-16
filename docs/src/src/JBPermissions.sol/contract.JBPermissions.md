# JBPermissions
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBPermissions.sol)

**Inherits:**
[IJBPermissions](/src/interfaces/IJBPermissions.sol/interface.IJBPermissions.md)

Stores permissions for all addresses and operators. Addresses can give permissions to any other address
(i.e. an *operator*) to execute specific operations on their behalf.


## State Variables
### WILDCARD_PROJECT_ID
The project ID considered a wildcard, meaning it will grant permissions to all projects.


```solidity
uint256 public constant override WILDCARD_PROJECT_ID = 0;
```


### permissionsOf
The permissions that an operator has been given by an account for a specific project.

*An account can give an operator permissions that only pertain to a specific project ID.*

*There is no project with a ID of 0 – this ID is a wildcard which gives an operator permissions pertaining
to *all* project IDs on an account's behalf. Use this with caution.*

*Permissions are stored in a packed `uint256`. Each of the 256 bits represents the on/off state of a
permission. Applications can specify the significance of each permission ID.*


```solidity
mapping(address operator => mapping(address account => mapping(uint256 projectId => uint256))) public override
    permissionsOf;
```


## Functions
### hasPermission

Check if an operator has a specific permission for a specific address and project ID.


```solidity
function hasPermission(
    address operator,
    address account,
    uint256 projectId,
    uint256 permissionId,
    bool includeRoot,
    bool includeWildcardProjectId
)
    public
    view
    override
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|The operator to check.|
|`account`|`address`|The account being operated on behalf of.|
|`projectId`|`uint256`|The project ID that the operator has permission to operate under. 0 represents all projects.|
|`permissionId`|`uint256`|The permission ID to check for.|
|`includeRoot`|`bool`|A flag indicating if the return value should default to true if the operator has the ROOT permission.|
|`includeWildcardProjectId`|`bool`|A flag indicating if the return value should return true if the operator has the specified permission on the wildcard project ID.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating whether the operator has the specified permission.|


### hasPermissions

Check if an operator has all of the specified permissions for a specific address and project ID.


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
    override
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`operator`|`address`|The operator to check.|
|`account`|`address`|The account being operated on behalf of.|
|`projectId`|`uint256`|The project ID that the operator has permission to operate under. 0 represents all projects.|
|`permissionIds`|`uint256[]`|An array of permission IDs to check for.|
|`includeRoot`|`bool`|A flag indicating if the return value should default to true if the operator has the ROOT permission.|
|`includeWildcardProjectId`|`bool`|A flag indicating if the return value should return true if the operator has the specified permission on the wildcard project ID.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating whether the operator has all specified permissions.|


### _includesPermission

Checks if a permission is included in a packed permissions data.


```solidity
function _includesPermission(uint256 permissions, uint256 permissionId) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permissions`|`uint256`|The packed permissions to check.|
|`permissionId`|`uint256`|The ID of the permission to check for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating whether the permission is included.|


### _packedPermissions

Converts an array of permission IDs to a packed `uint256`.


```solidity
function _packedPermissions(uint8[] calldata permissionIds) internal pure returns (uint256 packed);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permissionIds`|`uint8[]`|The IDs of the permissions to pack.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`packed`|`uint256`|The packed value.|


### setPermissionsFor

Sets permissions for an operator.

*Only an address can give permissions to or revoke permissions from its operators.*


```solidity
function setPermissionsFor(address account, JBPermissionsData calldata permissionsData) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account setting its operators' permissions.|
|`permissionsData`|`JBPermissionsData`|The data which specifies the permissions the operator is being given.|


## Errors
### JBPermissions_CantSetRootPermissionForWildcardProject

```solidity
error JBPermissions_CantSetRootPermissionForWildcardProject();
```

### JBPermissions_NoZeroPermission

```solidity
error JBPermissions_NoZeroPermission();
```

### JBPermissions_PermissionIdOutOfBounds

```solidity
error JBPermissions_PermissionIdOutOfBounds(uint256 permissionId);
```

### JBPermissions_Unauthorized

```solidity
error JBPermissions_Unauthorized();
```

