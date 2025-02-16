# JBChainlinkV3PriceFeed
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBChainlinkV3PriceFeed.sol)

**Inherits:**
[IJBPriceFeed](/src/interfaces/IJBPriceFeed.sol/interface.IJBPriceFeed.md)

An `IJBPriceFeed` implementation that reports prices from a Chainlink `AggregatorV3Interface`.


## State Variables
### FEED
The Chainlink feed that prices are reported from.


```solidity
AggregatorV3Interface public immutable FEED;
```


### THRESHOLD
How many seconds old a Chainlink price update is allowed to be before considered "stale".


```solidity
uint256 public immutable THRESHOLD;
```


## Functions
### constructor


```solidity
constructor(AggregatorV3Interface feed, uint256 threshold);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feed`|`AggregatorV3Interface`|The Chainlink feed to report prices from.|
|`threshold`|`uint256`|How many seconds old a price update may be.|


### currentUnitPrice

Gets the current price (per 1 unit) from the feed.


```solidity
function currentUnitPrice(uint256 decimals) public view virtual override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`decimals`|`uint256`|The number of decimals the return value should use.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current unit price from the feed, as a fixed point number with the specified number of decimals.|


## Errors
### JBChainlinkV3PriceFeed_IncompleteRound

```solidity
error JBChainlinkV3PriceFeed_IncompleteRound();
```

### JBChainlinkV3PriceFeed_NegativePrice

```solidity
error JBChainlinkV3PriceFeed_NegativePrice(int256 price);
```

### JBChainlinkV3PriceFeed_StalePrice

```solidity
error JBChainlinkV3PriceFeed_StalePrice(uint256 timestamp, uint256 threshold, uint256 updatedAt);
```

