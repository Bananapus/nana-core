# IJBTokens
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBTokens.sol)


## Functions
### creditBalanceOf


```solidity
function creditBalanceOf(address holder, uint256 projectId) external view returns (uint256);
```

### projectIdOf


```solidity
function projectIdOf(IJBToken token) external view returns (uint256);
```

### tokenOf


```solidity
function tokenOf(uint256 projectId) external view returns (IJBToken);
```

### totalCreditSupplyOf


```solidity
function totalCreditSupplyOf(uint256 projectId) external view returns (uint256);
```

### totalBalanceOf


```solidity
function totalBalanceOf(address holder, uint256 projectId) external view returns (uint256 result);
```

### totalSupplyOf


```solidity
function totalSupplyOf(uint256 projectId) external view returns (uint256);
```

### burnFrom


```solidity
function burnFrom(address holder, uint256 projectId, uint256 count) external;
```

### claimTokensFor


```solidity
function claimTokensFor(address holder, uint256 projectId, uint256 count, address beneficiary) external;
```

### deployERC20For


```solidity
function deployERC20For(
    uint256 projectId,
    string calldata name,
    string calldata symbol,
    bytes32 salt
)
    external
    returns (IJBToken token);
```

### mintFor


```solidity
function mintFor(address holder, uint256 projectId, uint256 count) external returns (IJBToken token);
```

### setTokenFor


```solidity
function setTokenFor(uint256 projectId, IJBToken token) external;
```

### transferCreditsFrom


```solidity
function transferCreditsFrom(address holder, uint256 projectId, address recipient, uint256 count) external;
```

## Events
### DeployERC20

```solidity
event DeployERC20(
    uint256 indexed projectId, IJBToken indexed token, string name, string symbol, bytes32 salt, address caller
);
```

### Burn

```solidity
event Burn(
    address indexed holder,
    uint256 indexed projectId,
    uint256 count,
    uint256 creditBalance,
    uint256 tokenBalance,
    address caller
);
```

### ClaimTokens

```solidity
event ClaimTokens(
    address indexed holder,
    uint256 indexed projectId,
    uint256 creditBalance,
    uint256 count,
    address beneficiary,
    address caller
);
```

### Mint

```solidity
event Mint(address indexed holder, uint256 indexed projectId, uint256 count, bool tokensWereClaimed, address caller);
```

### SetToken

```solidity
event SetToken(uint256 indexed projectId, IJBToken indexed token, address caller);
```

### TransferCredits

```solidity
event TransferCredits(
    address indexed holder, uint256 indexed projectId, address indexed recipient, uint256 count, address caller
);
```

