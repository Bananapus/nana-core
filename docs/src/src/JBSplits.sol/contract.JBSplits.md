# JBSplits
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBSplits.sol)

**Inherits:**
[JBControlled](/src/abstract/JBControlled.sol/abstract.JBControlled.md), [IJBSplits](/src/interfaces/IJBSplits.sol/interface.IJBSplits.md)

Stores and manages splits for each project.


## State Variables
### FALLBACK_RULESET_ID
The ID of the ruleset that will be checked if nothing was found in the provided rulesetId.


```solidity
uint256 public constant override FALLBACK_RULESET_ID = 0;
```


### _packedSplitParts1Of
Packed split data given the split's project, ruleset, and group IDs, as well as the split's index within
that group.

*`preferAddToBalance` in bit 0, `percent` in bits 1-32, `projectId` in bits 33-88, and `beneficiary` in bits
89-248*

**Note:**
return: The split's `preferAddToBalance`, `percent`, `projectId`, and `beneficiary` packed into one
`uint256`.


```solidity
mapping(
    uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => mapping(uint256 index => uint256)))
) internal _packedSplitParts1Of;
```


### _packedSplitParts2Of
More packed split data given the split's project, ruleset, and group IDs, as well as the split's index
within that group.

*`lockedUntil` in bits 0-47, `hook` address in bits 48-207.*

*This packed data is often 0.*

**Note:**
return: The split's `lockedUntil` and `hook` packed into one `uint256`.


```solidity
mapping(
    uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => mapping(uint256 index => uint256)))
) internal _packedSplitParts2Of;
```


### _splitCountOf
The number of splits currently stored in a group given a project ID, ruleset ID, and group ID.


```solidity
mapping(uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => uint256))) internal _splitCountOf;
```


## Functions
### constructor


```solidity
constructor(IJBDirectory directory) JBControlled(directory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing directories of terminals and controllers for each project.|


### splitsOf

Get the split structs for the specified project ID, within the specified ruleset, for the specified
group. The splits stored at ruleset 0 are used by default during a ruleset if the splits for the specific
ruleset aren't set.

*If splits aren't found at the given `rulesetId`, they'll be sought in the FALLBACK_RULESET_ID of 0.*


```solidity
function splitsOf(
    uint256 projectId,
    uint256 rulesetId,
    uint256 groupId
)
    external
    view
    override
    returns (JBSplit[] memory splits);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get splits for.|
|`rulesetId`|`uint256`|An identifier within which the returned splits should be considered active.|
|`groupId`|`uint256`|The identifying group of the splits.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`splits`|`JBSplit[]`|An array of all splits for the project.|


### _getStructsFor

Unpack an array of `JBSplit` structs for all of the splits in a group, given project, ruleset, and group
IDs.


```solidity
function _getStructsFor(
    uint256 projectId,
    uint256 rulesetId,
    uint256 groupId
)
    internal
    view
    returns (JBSplit[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project the splits belong to.|
|`rulesetId`|`uint256`|The ID of the ruleset the group of splits should be considered active within.|
|`groupId`|`uint256`|The ID of the group to get the splits structs of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBSplit[]`|splits The split structs, as an array of `JBSplit`s.|


### _includesLockedSplits

Determine if the provided splits array includes the locked split.


```solidity
function _includesLockedSplits(JBSplit[] memory splits, JBSplit memory lockedSplit) internal pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`splits`|`JBSplit[]`|The array of splits to check within.|
|`lockedSplit`|`JBSplit`|The locked split.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating if the `lockedSplit` is contained in the `splits`.|


### setSplitGroupsOf

Sets a project's split groups.

*Only a project's controller can set its splits.*

*The new split groups must include any currently set splits that are locked.*


```solidity
function setSplitGroupsOf(
    uint256 projectId,
    uint256 rulesetId,
    JBSplitGroup[] calldata splitGroups
)
    external
    override
    onlyControllerOf(projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to set the split groups of.|
|`rulesetId`|`uint256`|The ID of the ruleset the split groups should be active in. Send 0 to set the default split that'll be active if no ruleset has specific splits set. The default's default is the project's owner.|
|`splitGroups`|`JBSplitGroup[]`|An array of split groups to set.|


### _setSplitsOf

Sets the splits for a group given a project, ruleset, and group ID.

*The new splits must include any currently set splits that are locked.*

*The sum of the split `percent`s within one group must be less than 100%.*


```solidity
function _setSplitsOf(uint256 projectId, uint256 rulesetId, uint256 groupId, JBSplit[] memory splits) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project splits are being set for.|
|`rulesetId`|`uint256`|The ID of the ruleset the splits should be considered active within.|
|`groupId`|`uint256`|The ID of the group to set the splits within.|
|`splits`|`JBSplit[]`|An array of splits to set.|


## Errors
### JBSplits_TotalPercentExceeds100

```solidity
error JBSplits_TotalPercentExceeds100();
```

### JBSplits_PreviousLockedSplitsNotIncluded

```solidity
error JBSplits_PreviousLockedSplitsNotIncluded();
```

### JBSplits_ZeroSplitPercent

```solidity
error JBSplits_ZeroSplitPercent();
```

