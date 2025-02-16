# IJBDirectory
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBDirectory.sol)


## Functions
### PROJECTS


```solidity
function PROJECTS() external view returns (IJBProjects);
```

### controllerOf


```solidity
function controllerOf(uint256 projectId) external view returns (IERC165);
```

### isAllowedToSetFirstController


```solidity
function isAllowedToSetFirstController(address account) external view returns (bool);
```

### isTerminalOf


```solidity
function isTerminalOf(uint256 projectId, IJBTerminal terminal) external view returns (bool);
```

### primaryTerminalOf


```solidity
function primaryTerminalOf(uint256 projectId, address token) external view returns (IJBTerminal);
```

### terminalsOf


```solidity
function terminalsOf(uint256 projectId) external view returns (IJBTerminal[] memory);
```

### setControllerOf


```solidity
function setControllerOf(uint256 projectId, IERC165 controller) external;
```

### setIsAllowedToSetFirstController


```solidity
function setIsAllowedToSetFirstController(address account, bool flag) external;
```

### setPrimaryTerminalOf


```solidity
function setPrimaryTerminalOf(uint256 projectId, address token, IJBTerminal terminal) external;
```

### setTerminalsOf


```solidity
function setTerminalsOf(uint256 projectId, IJBTerminal[] calldata terminals) external;
```

## Events
### AddTerminal

```solidity
event AddTerminal(uint256 indexed projectId, IJBTerminal indexed terminal, address caller);
```

### SetController

```solidity
event SetController(uint256 indexed projectId, IERC165 indexed controller, address caller);
```

### SetIsAllowedToSetFirstController

```solidity
event SetIsAllowedToSetFirstController(address indexed addr, bool indexed isAllowed, address caller);
```

### SetPrimaryTerminal

```solidity
event SetPrimaryTerminal(
    uint256 indexed projectId, address indexed token, IJBTerminal indexed terminal, address caller
);
```

### SetTerminals

```solidity
event SetTerminals(uint256 indexed projectId, IJBTerminal[] terminals, address caller);
```

