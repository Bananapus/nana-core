# JBMetadataResolver
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/libraries/JBMetadataResolver.sol)

Library to parse and create metadata to store {id: data} entries.

*Metadata are built as:
- 32B of reserved space for the protocol
- a lookup table `Id: offset`, defining the offset of the data for a given 4 bytes id.
The offset fits 1 bytes, the ID 4 bytes. This table is padded to 32B.
- the data for each id, padded to 32B each
+-----------------------+ offset: 0
| 32B reserved          |
+-----------------------+ offset: 1 = end of first 32B
|      (ID1,offset1)    |
|      (ID2,offset2)    |
|       0's padding     |
+-----------------------+ offset: offset1 = 1 + number of words taken by the padded table
|       id1 data1       |
| 0's padding           |
+-----------------------+ offset: offset2 = offset1 + number of words taken by the data1
|       id2 data2       |
| 0's padding           |
+-----------------------+*


## State Variables
### ID_SIZE

```solidity
uint256 constant ID_SIZE = 4;
```


### ID_OFFSET_SIZE

```solidity
uint256 constant ID_OFFSET_SIZE = 1;
```


### WORD_SIZE

```solidity
uint256 constant WORD_SIZE = 32;
```


### TOTAL_ID_SIZE

```solidity
uint256 constant TOTAL_ID_SIZE = 5;
```


### NEXT_ID_OFFSET

```solidity
uint256 constant NEXT_ID_OFFSET = 9;
```


### RESERVED_SIZE

```solidity
uint256 constant RESERVED_SIZE = 32;
```


### MIN_METADATA_LENGTH

```solidity
uint256 constant MIN_METADATA_LENGTH = 37;
```


## Functions
### addToMetadata

Add an {id: data} entry to an existing metadata. This is an append-only mechanism.


```solidity
function addToMetadata(
    bytes memory originalMetadata,
    bytes4 idToAdd,
    bytes memory dataToAdd
)
    internal
    pure
    returns (bytes memory newMetadata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`originalMetadata`|`bytes`|The original metadata|
|`idToAdd`|`bytes4`|The id to add|
|`dataToAdd`|`bytes`|The data to add|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`newMetadata`|`bytes`|The new metadata with the entry added|


### createMetadata

Create the metadata for a list of {id:data}

*Intended for offchain use (gas heavy)*


```solidity
function createMetadata(bytes4[] memory ids, bytes[] memory datas) internal pure returns (bytes memory metadata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`ids`|`bytes4[]`|The list of ids|
|`datas`|`bytes[]`|The list of corresponding datas|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`metadata`|`bytes`|The resulting metadata|


### getDataFor

Parse the metadata to find the data for a specific ID

*Returns false and an empty bytes if no data is found*


```solidity
function getDataFor(bytes4 id, bytes memory metadata) internal pure returns (bool found, bytes memory targetData);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`id`|`bytes4`|The ID to find.|
|`metadata`|`bytes`|The metadata to parse.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`found`|`bool`|Whether the {id:data} was found|
|`targetData`|`bytes`|The data for the ID (can be empty)|


### getId

Returns an unique id following a suggested format (`xor(address(this), purpose name)` where purpose name
is a string giving context to the id (Permit2, quoteForSwap, etc)


```solidity
function getId(string memory purpose) internal view returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`purpose`|`string`|A string describing the purpose associated with the id|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|id The resulting ID.|


### getId

Returns an unique id following a suggested format (`xor(address(this), purpose name)` where purpose name
is a string giving context to the id (Permit2, quoteForSwap, etc)


```solidity
function getId(string memory purpose, address target) internal pure returns (bytes4);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`purpose`|`string`|A string describing the purpose associated with the id|
|`target`|`address`|The target which will use the metadata|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes4`|id The resulting ID.|


### _sliceBytes

Slice bytes from a start index to an end index.


```solidity
function _sliceBytes(bytes memory data, uint256 start, uint256 end) private pure returns (bytes memory slicedBytes);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`bytes`|The bytes array to slice|
|`start`|`uint256`|The start index to slice at.|
|`end`|`uint256`|The end index to slice at.|


## Errors
### JBMetadataResolver_DataNotPadded

```solidity
error JBMetadataResolver_DataNotPadded();
```

### JBMetadataResolver_LengthMismatch

```solidity
error JBMetadataResolver_LengthMismatch();
```

### JBMetadataResolver_MetadataTooLong

```solidity
error JBMetadataResolver_MetadataTooLong();
```

### JBMetadataResolver_MetadataTooShort

```solidity
error JBMetadataResolver_MetadataTooShort();
```

