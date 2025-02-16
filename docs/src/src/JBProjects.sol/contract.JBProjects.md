# JBProjects
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBProjects.sol)

**Inherits:**
ERC721, Ownable, [IJBProjects](/src/interfaces/IJBProjects.sol/interface.IJBProjects.md)

Stores project ownership and metadata.

*Projects are represented as ERC-721s.*


## State Variables
### count
The number of projects that have been created using this contract.

*The count is incremented with each new project created.*

*The resulting ERC-721 token ID for each project is the newly incremented count value.*


```solidity
uint256 public override count;
```


### tokenUriResolver
The contract resolving each project ID to its ERC721 URI.


```solidity
IJBTokenUriResolver public override tokenUriResolver;
```


## Functions
### constructor


```solidity
constructor(address owner, address feeProjectOwner) ERC721("Juicebox Projects", "JUICEBOX") Ownable(owner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The owner of the contract who can set metadata.|
|`feeProjectOwner`|`address`|The address that will receive the fee-project. If `address(0)` the fee-project will not be minted.|


### supportsInterface

Indicates whether this contract adheres to the specified interface.

*See [IERC165-supportsInterface](/src/JBFeelessAddresses.sol/contract.JBFeelessAddresses.md#supportsinterface).*


```solidity
function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|The ID of the interface to check for adherence to.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating if the provided interface ID is supported.|


### tokenURI

Returns the URI where the ERC-721 standard JSON of a project is hosted.


```solidity
function tokenURI(uint256 projectId) public view override returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get a URI of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|The token URI to use for the provided `projectId`.|


### setTokenUriResolver

Sets the address of the resolver used to retrieve the tokenURI of projects.


```solidity
function setTokenUriResolver(IJBTokenUriResolver resolver) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`resolver`|`IJBTokenUriResolver`|The address of the new resolver.|


### createFor

Create a new project for the specified owner, which mints an NFT (ERC-721) into their wallet.

*Anyone can create a project on an owner's behalf.*


```solidity
function createFor(address owner) public override returns (uint256 projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The address that will be the owner of the project.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The token ID of the newly created project.|


