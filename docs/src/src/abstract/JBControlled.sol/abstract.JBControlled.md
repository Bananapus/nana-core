# JBControlled
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/abstract/JBControlled.sol)

**Inherits:**
[IJBControlled](/src/interfaces/IJBControlled.sol/interface.IJBControlled.md)

Provides a modifier for contracts with functionality that can only be accessed by a project's controller.


## State Variables
### DIRECTORY
The directory of terminals and controllers for projects.


```solidity
IJBDirectory public immutable override DIRECTORY;
```


## Functions
### onlyControllerOf

Only allows the controller of the specified project to proceed.


```solidity
modifier onlyControllerOf(uint256 projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project.|


### constructor


```solidity
constructor(IJBDirectory directory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing directories of terminals and controllers for each project.|


### _onlyControllerOf

Only allows the controller of the specified project to proceed.


```solidity
function _onlyControllerOf(uint256 projectId) internal view;
```

## Errors
### JBControlled_ControllerUnauthorized

```solidity
error JBControlled_ControllerUnauthorized(address controller);
```

