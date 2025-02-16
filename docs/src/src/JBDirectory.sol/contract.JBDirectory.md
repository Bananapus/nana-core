# JBDirectory
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBDirectory.sol)

**Inherits:**
[JBPermissioned](/src/abstract/JBPermissioned.sol/abstract.JBPermissioned.md), Ownable, [IJBDirectory](/src/interfaces/IJBDirectory.sol/interface.IJBDirectory.md)

`JBDirectory` tracks the terminals and the controller used by each project.

*Tracks which `IJBTerminal`s each project is currently accepting funds through, and which `IJBController` is
managing each project's tokens and rulesets.*


## State Variables
### PROJECTS
Mints ERC-721s that represent project ownership and transfers.


```solidity
IJBProjects public immutable override PROJECTS;
```


### controllerOf
The specified project's controller, which dictates how its terminals interact with its tokens and
rulesets.


```solidity
mapping(uint256 projectId => IERC165) public override controllerOf;
```


### isAllowedToSetFirstController
Whether the specified address is allowed to set a project's first controller on their behalf.

*These addresses/contracts have been vetted by this contract's owner.*


```solidity
mapping(address addr => bool) public override isAllowedToSetFirstController;
```


### _primaryTerminalOf
The primary terminal that a project uses for the specified token.


```solidity
mapping(uint256 projectId => mapping(address token => IJBTerminal)) internal _primaryTerminalOf;
```


### _terminalsOf
The specified project's terminals.


```solidity
mapping(uint256 projectId => IJBTerminal[]) internal _terminalsOf;
```


## Functions
### constructor


```solidity
constructor(
    IJBPermissions permissions,
    IJBProjects projects,
    address owner
)
    JBPermissioned(permissions)
    Ownable(owner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`permissions`|`IJBPermissions`|A contract storing permissions.|
|`projects`|`IJBProjects`|A contract which mints ERC-721s that represent project ownership and transfers.|
|`owner`|`address`|The address that will own the contract.|


### primaryTerminalOf

The primary terminal that a project uses for the specified token.

*Returns the first terminal that accepts the token if the project hasn't explicitly set a primary terminal
for it.*

*Returns the zero address if no terminal accepts the token.*


```solidity
function primaryTerminalOf(uint256 projectId, address token) external view override returns (IJBTerminal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the primary terminal of.|
|`token`|`address`|The token that the terminal accepts.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IJBTerminal`|The primary terminal's address.|


### terminalsOf

The specified project's terminals.


```solidity
function terminalsOf(uint256 projectId) external view override returns (IJBTerminal[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the terminals of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IJBTerminal[]`|An array of the project's terminal addresses.|


### isTerminalOf

Check if a project uses a specific terminal.


```solidity
function isTerminalOf(uint256 projectId, IJBTerminal terminal) public view override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|
|`terminal`|`IJBTerminal`|The terminal to check for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating whether the project uses the terminal.|


### setIsAllowedToSetFirstController

Add or remove an address/contract from a list of trusted addresses which are allowed to set a first
controller for projects.

*Only this contract's owner can call this function.*

*These addresses are vetted controllers as well as contracts designed to launch new projects.*

*A project can set its own controller without being on this list.*

*If you would like to add an address/contract to this list, please reach out to this contract's owner.*


```solidity
function setIsAllowedToSetFirstController(address addr, bool flag) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to allow or not allow.|
|`flag`|`bool`|Whether the address is allowed to set first controllers for projects. Use `true` to allow and `false` to not allow.|


### setControllerOf

Set a project's controller. Controllers manage how terminals interact with tokens and rulesets.

*Can only be called if:
- The ruleset's metadata has `allowSetController` enabled, and the message's sender is the project's owner or an
address with the owner's permission to `SET_CONTROLLER`.
- OR the message's sender is the project's current controller.
- OR an address which `isAllowedToSetFirstController` is setting a project's first controller.*


```solidity
function setControllerOf(uint256 projectId, IERC165 controller) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose controller is being set.|
|`controller`|`IERC165`|The address of the controller to set.|


### setPrimaryTerminalOf

Set a project's primary terminal for a token.

*The primary terminal for a token is where payments in that token are routed to by default.*

*This is useful in cases where a project has multiple terminals which accept the same token.*

*Can only be called by the project's owner, or an address with the owner's permission to
`SET_PRIMARY_TERMINAL`.*


```solidity
function setPrimaryTerminalOf(uint256 projectId, address token, IJBTerminal terminal) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose primary terminal is being set.|
|`token`|`address`|The token to set the primary terminal for.|
|`terminal`|`IJBTerminal`|The terminal being set as the primary terminal.|


### setTerminalsOf

Set a project's terminals.

*Can only be called by the project's owner, an address with the owner's permission to `SET_TERMINALS`, or
the project's controller.*

*Unless the caller is the project's controller, the project's ruleset must allow setting terminals.*


```solidity
function setTerminalsOf(uint256 projectId, IJBTerminal[] calldata terminals) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose terminals are being set.|
|`terminals`|`IJBTerminal[]`|An array of terminal addresses to set for the project.|


### _addTerminalIfNeeded

If a terminal hasn't already been added to a project's list of terminals, add it.

*The project's ruleset must have `allowSetTerminals` set to `true`.*


```solidity
function _addTerminalIfNeeded(uint256 projectId, IJBTerminal terminal) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to add the terminal to.|
|`terminal`|`IJBTerminal`|The terminal to add.|


## Errors
### JBDirectory_DuplicateTerminals

```solidity
error JBDirectory_DuplicateTerminals(IJBTerminal terminal);
```

### JBDirectory_InvalidProjectIdInDirectory

```solidity
error JBDirectory_InvalidProjectIdInDirectory(uint256 projectId, uint256 limit);
```

### JBDirectory_SetControllerNotAllowed

```solidity
error JBDirectory_SetControllerNotAllowed();
```

### JBDirectory_SetTerminalsNotAllowed

```solidity
error JBDirectory_SetTerminalsNotAllowed();
```

### JBDirectory_TokenNotAccepted

```solidity
error JBDirectory_TokenNotAccepted(uint256 projectId, address token, IJBTerminal terminal);
```

