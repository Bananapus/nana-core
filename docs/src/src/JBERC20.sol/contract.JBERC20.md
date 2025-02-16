# JBERC20
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBERC20.sol)

**Inherits:**
ERC20Votes, ERC20Permit, Ownable, [IJBToken](/src/interfaces/IJBToken.sol/interface.IJBToken.md)

An ERC-20 token that can be used by a project in `JBTokens` and `JBController`.

*By default, a project uses "credits" to track balances. Once a project sets their `IJBToken` using
`JBController.deployERC20For(...)` or `JBController.setTokenFor(...)`, credits can be redeemed to claim tokens.*

*`JBController.deployERC20For(...)` deploys a `JBERC20` contract and sets it as the project's token.*


## State Variables
### _name
The token's name.


```solidity
string private _name;
```


### _symbol
The token's symbol.


```solidity
string private _symbol;
```


## Functions
### constructor


```solidity
constructor() Ownable(address(this)) ERC20("invalid", "invalid") ERC20Permit("JBToken");
```

### balanceOf

The balance of the given address.


```solidity
function balanceOf(address account) public view override(ERC20, IJBToken) returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The account to get the balance of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The number of tokens owned by the `account`, as a fixed point number with 18 decimals.|


### canBeAddedTo

This token can only be added to a project when its created by the `JBTokens` contract.


```solidity
function canBeAddedTo(uint256) external pure override returns (bool);
```

### decimals

The number of decimals used for this token's fixed point accounting.


```solidity
function decimals() public view override(ERC20, IJBToken) returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimals.|


### name

The token's name.


```solidity
function name() public view virtual override returns (string memory);
```

### symbol

The token's symbol.


```solidity
function symbol() public view virtual override returns (string memory);
```

### totalSupply

The total supply of this ERC20 i.e. the total number of tokens in existence.


```solidity
function totalSupply() public view override(ERC20, IJBToken) returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply of this ERC20, as a fixed point number.|


### burn

Burn some outstanding tokens.

*Can only be called by this contract's owner.*


```solidity
function burn(address account, uint256 amount) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to burn tokens from.|
|`amount`|`uint256`|The amount of tokens to burn, as a fixed point number with 18 decimals.|


### mint

Mints more of this token.

*Can only be called by this contract's owner.*


```solidity
function mint(address account, uint256 amount) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|The address to mint the new tokens to.|
|`amount`|`uint256`|The amount of tokens to mint, as a fixed point number with 18 decimals.|


### initialize

Initializes the token.


```solidity
function initialize(string memory name_, string memory symbol_, address owner) public override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name_`|`string`|The token's name.|
|`symbol_`|`string`|The token's symbol.|
|`owner`|`address`|The token contract's owner.|


### nonces

Required override.


```solidity
function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256);
```

### _update

Required override.


```solidity
function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Votes);
```

