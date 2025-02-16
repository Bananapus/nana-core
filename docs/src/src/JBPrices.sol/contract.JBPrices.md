# JBPrices
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBPrices.sol)

**Inherits:**
[JBControlled](/src/abstract/JBControlled.sol/abstract.JBControlled.md), [JBPermissioned](/src/abstract/JBPermissioned.sol/abstract.JBPermissioned.md), Ownable, [IJBPrices](/src/interfaces/IJBPrices.sol/interface.IJBPrices.md)

Manages and normalizes price feeds. Price feeds are contracts which return the "pricing currency" cost of 1
"unit currency".


## State Variables
### DEFAULT_PROJECT_ID
The ID to store default values in.


```solidity
uint256 public constant override DEFAULT_PROJECT_ID = 0;
```


### PROJECTS
Mints ERC-721s that represent project ownership and transfers.


```solidity
IJBProjects public immutable override PROJECTS;
```


### priceFeedFor
The available price feeds.

*The feed returns the `pricingCurrency` cost for one unit of the `unitCurrency`.*


```solidity
mapping(uint256 projectId => mapping(uint256 pricingCurrency => mapping(uint256 unitCurrency => IJBPriceFeed)))
    public
    override priceFeedFor;
```


## Functions
### constructor


```solidity
constructor(
    IJBDirectory directory,
    IJBPermissions permissions,
    IJBProjects projects,
    address owner
)
    JBControlled(directory)
    JBPermissioned(permissions)
    Ownable(owner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing directories of terminals and controllers for each project.|
|`permissions`|`IJBPermissions`|A contract storing permissions.|
|`projects`|`IJBProjects`|A contract which mints ERC-721s that represent project ownership and transfers.|
|`owner`|`address`|The address that will own the contract.|


### pricePerUnitOf

Gets the `pricingCurrency` cost for one unit of the `unitCurrency`.


```solidity
function pricePerUnitOf(
    uint256 projectId,
    uint256 pricingCurrency,
    uint256 unitCurrency,
    uint256 decimals
)
    public
    view
    override
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check the feed for. Feeds stored in ID 0 are used by default for all projects.|
|`pricingCurrency`|`uint256`|The currency the feed's resulting price is in terms of.|
|`unitCurrency`|`uint256`|The currency being priced by the feed.|
|`decimals`|`uint256`|The number of decimals the returned fixed point price should include.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The `pricingCurrency` price of 1 `unitCurrency`, as a fixed point number with the specified number of decimals.|


### addPriceFeedFor

Add a price feed for the `unitCurrency`, priced in terms of the `pricingCurrency`.

*Price feeds can only be added, not modified or removed.*

*This contract's owner can add protocol-wide default price feed by passing a `projectId` of 0.*


```solidity
function addPriceFeedFor(
    uint256 projectId,
    uint256 pricingCurrency,
    uint256 unitCurrency,
    IJBPriceFeed feed
)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to add a feed for. If `projectId` is 0, add a protocol-wide default price feed.|
|`pricingCurrency`|`uint256`|The currency the feed's output price is in terms of.|
|`unitCurrency`|`uint256`|The currency being priced by the feed.|
|`feed`|`IJBPriceFeed`|The address of the price feed to add.|


## Errors
### JBPrices_PriceFeedAlreadyExists

```solidity
error JBPrices_PriceFeedAlreadyExists(IJBPriceFeed feed);
```

### JBPrices_PriceFeedNotFound

```solidity
error JBPrices_PriceFeedNotFound();
```

### JBPrices_ZeroPricingCurrency

```solidity
error JBPrices_ZeroPricingCurrency();
```

### JBPrices_ZeroUnitCurrency

```solidity
error JBPrices_ZeroUnitCurrency();
```

