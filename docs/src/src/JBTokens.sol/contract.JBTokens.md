# JBTokens
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBTokens.sol)

**Inherits:**
[JBControlled](/src/abstract/JBControlled.sol/abstract.JBControlled.md), [IJBTokens](/src/interfaces/IJBTokens.sol/interface.IJBTokens.md)

Manages minting, burning, and balances of projects' tokens and token credits.

*Token balances can either be ERC-20s or token credits. This contract manages these two representations and
allows credit -> ERC-20 claiming.*

*The total supply of a project's tokens and the balance of each account are calculated in this contract.*

*An ERC-20 contract must be set by a project's owner for ERC-20 claiming to become available. Projects can bring
their own IJBToken if they prefer.*


## State Variables
### TOKEN
A reference to the token implementation that'll be cloned as projects deploy their own tokens.


```solidity
IJBToken public immutable TOKEN;
```


### creditBalanceOf
Each holder's credit balance for each project.


```solidity
mapping(address holder => mapping(uint256 projectId => uint256)) public override creditBalanceOf;
```


### projectIdOf
Each token's project.


```solidity
mapping(IJBToken token => uint256) public override projectIdOf;
```


### tokenOf
Each project's attached token contract.


```solidity
mapping(uint256 projectId => IJBToken) public override tokenOf;
```


### totalCreditSupplyOf
The total supply of credits for each project.


```solidity
mapping(uint256 projectId => uint256) public override totalCreditSupplyOf;
```


## Functions
### constructor


```solidity
constructor(IJBDirectory directory, IJBToken token) JBControlled(directory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing directories of terminals and controllers for each project.|
|`token`|`IJBToken`|The implementation of the token contract that project can deploy.|


### totalBalanceOf

The total balance a holder has for a specified project, including both tokens and token credits.


```solidity
function totalBalanceOf(address holder, uint256 projectId) external view override returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The holder to get a balance for.|
|`projectId`|`uint256`|The project to get the `_holder`s balance for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The combined token and token credit balance of the `_holder|


### totalSupplyOf

The total supply for a specific project, including both tokens and token credits.


```solidity
function totalSupplyOf(uint256 projectId) public view override returns (uint256 totalSupply);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the total supply of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`totalSupply`|`uint256`|The total supply of the project's tokens and token credits.|


### burnFrom

Burns (destroys) credits or tokens.

*Credits are burned first, then tokens are burned.*

*Only a project's current controller can burn its tokens.*


```solidity
function burnFrom(address holder, uint256 projectId, uint256 count) external override onlyControllerOf(projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address that owns the tokens which are being burned.|
|`projectId`|`uint256`|The ID of the project to the burned tokens belong to.|
|`count`|`uint256`|The number of tokens to burn.|


### claimTokensFor

Redeem credits to claim tokens into a holder's wallet.

*Only a project's controller can claim that project's tokens.*


```solidity
function claimTokensFor(
    address holder,
    uint256 projectId,
    uint256 count,
    address beneficiary
)
    external
    override
    onlyControllerOf(projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The owner of the credits being redeemed.|
|`projectId`|`uint256`|The ID of the project whose tokens are being claimed.|
|`count`|`uint256`|The number of tokens to claim.|
|`beneficiary`|`address`|The account into which the claimed tokens will go.|


### deployERC20For

Deploys an ERC-20 token for a project. It will be used when claiming tokens.

*Deploys a project's ERC-20 token contract.*

*Only a project's controller can deploy its token.*


```solidity
function deployERC20For(
    uint256 projectId,
    string calldata name,
    string calldata symbol,
    bytes32 salt
)
    external
    override
    onlyControllerOf(projectId)
    returns (IJBToken token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to deploy an ERC-20 token for.|
|`name`|`string`|The ERC-20's name.|
|`symbol`|`string`|The ERC-20's symbol.|
|`salt`|`bytes32`|The salt used for ERC-1167 clone deployment. Pass a non-zero salt for deterministic deployment based on `msg.sender` and the `TOKEN` implementation address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IJBToken`|The address of the token that was deployed.|


### mintFor

Mint (create) new tokens or credits.

*Only a project's current controller can mint its tokens.*


```solidity
function mintFor(
    address holder,
    uint256 projectId,
    uint256 count
)
    external
    override
    onlyControllerOf(projectId)
    returns (IJBToken token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address receiving the new tokens.|
|`projectId`|`uint256`|The ID of the project to which the tokens belong.|
|`count`|`uint256`|The number of tokens to mint.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IJBToken`|The address of the token that was minted, if the project has a token.|


### setTokenFor

Set a project's token if not already set.

*Only a project's controller can set its token.*


```solidity
function setTokenFor(uint256 projectId, IJBToken token) external override onlyControllerOf(projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to set the token of.|
|`token`|`IJBToken`|The new token's address.|


### transferCreditsFrom

Allows a holder to transfer credits to another account.

*Only a project's controller can transfer credits for that project.*


```solidity
function transferCreditsFrom(
    address holder,
    uint256 projectId,
    address recipient,
    uint256 count
)
    external
    override
    onlyControllerOf(projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to transfer credits from.|
|`projectId`|`uint256`|The ID of the project whose credits are being transferred.|
|`recipient`|`address`|The recipient of the credits.|
|`count`|`uint256`|The number of token credits to transfer.|


## Errors
### JBTokens_EmptyName

```solidity
error JBTokens_EmptyName();
```

### JBTokens_EmptySymbol

```solidity
error JBTokens_EmptySymbol();
```

### JBTokens_EmptyToken

```solidity
error JBTokens_EmptyToken();
```

### JBTokens_InsufficientCredits

```solidity
error JBTokens_InsufficientCredits(uint256 count, uint256 creditBalance);
```

### JBTokens_InsufficientTokensToBurn

```solidity
error JBTokens_InsufficientTokensToBurn(uint256 count, uint256 tokenBalance);
```

### JBTokens_OverflowAlert

```solidity
error JBTokens_OverflowAlert(uint256 value, uint256 limit);
```

### JBTokens_ProjectAlreadyHasToken

```solidity
error JBTokens_ProjectAlreadyHasToken(IJBToken token);
```

### JBTokens_TokenAlreadyBeingUsed

```solidity
error JBTokens_TokenAlreadyBeingUsed(uint256 projectId);
```

### JBTokens_TokenCantBeAdded

```solidity
error JBTokens_TokenCantBeAdded(uint256 projectId);
```

### JBTokens_TokenNotFound

```solidity
error JBTokens_TokenNotFound();
```

### JBTokens_TokensMustHave18Decimals

```solidity
error JBTokens_TokensMustHave18Decimals(uint256 decimals);
```

