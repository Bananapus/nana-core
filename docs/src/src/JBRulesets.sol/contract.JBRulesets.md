# JBRulesets
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBRulesets.sol)

**Inherits:**
[JBControlled](/src/abstract/JBControlled.sol/abstract.JBControlled.md), [IJBRulesets](/src/interfaces/IJBRulesets.sol/interface.IJBRulesets.md)

Manages rulesets and queuing.

*Rulesets dictate how a project behaves for a period of time. To learn more about their functionality, see the
`JBRuleset` data structure.*

*Throughout this contract, `rulesetId` is an identifier for each ruleset. The `rulesetId` is the unix timestamp
when the ruleset was initialized.*

*`approvable` means a ruleset which may or may not be approved.*


## State Variables
### _WEIGHT_CUT_MULTIPLE_CACHE_LOOKUP_THRESHOLD
The number of weight cut percent multiples before a cached value is sought.


```solidity
uint256 internal constant _WEIGHT_CUT_MULTIPLE_CACHE_LOOKUP_THRESHOLD = 1000;
```


### _MAX_WEIGHT_CUT_MULTIPLE_CACHE_THRESHOLD
The maximum number of weight cut percent multiples that can be cached at a time.


```solidity
uint256 internal constant _MAX_WEIGHT_CUT_MULTIPLE_CACHE_THRESHOLD = 50_000;
```


### latestRulesetIdOf
The ID of the ruleset with the latest start time for a specific project, whether the ruleset has been
approved or not.

*If a project has multiple rulesets queued, the `latestRulesetIdOf` will be the last one. This is the
"changeable" cycle.*


```solidity
mapping(uint256 projectId => uint256) public override latestRulesetIdOf;
```


### _metadataOf
The metadata for each ruleset, packed into one storage slot.


```solidity
mapping(uint256 projectId => mapping(uint256 rulesetId => uint256)) internal _metadataOf;
```


### _packedIntrinsicPropertiesOf
The mechanism-added properties to manage and schedule each ruleset, packed into one storage slot.


```solidity
mapping(uint256 projectId => mapping(uint256 rulesetId => uint256)) internal _packedIntrinsicPropertiesOf;
```


### _packedUserPropertiesOf
The user-defined properties of each ruleset, packed into one storage slot.


```solidity
mapping(uint256 projectId => mapping(uint256 rulesetId => uint256)) internal _packedUserPropertiesOf;
```


### _weightCacheOf
Cached weight values to derive rulesets from.


```solidity
mapping(uint256 projectId => mapping(uint256 rulesetId => JBRulesetWeightCache)) internal _weightCacheOf;
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


### allOf

Get an array of a project's rulesets up to a maximum array size, sorted from latest to earliest.


```solidity
function allOf(
    uint256 projectId,
    uint256 startingId,
    uint256 size
)
    external
    view
    override
    returns (JBRuleset[] memory rulesets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the rulesets of.|
|`startingId`|`uint256`|The ID of the ruleset to begin with. This will be the latest ruleset in the result. If 0 is passed, the project's latest ruleset will be used.|
|`size`|`uint256`|The maximum number of rulesets to return.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rulesets`|`JBRuleset[]`|The rulesets as an array of `JBRuleset` structs.|


### currentApprovalStatusForLatestRulesetOf

The current approval status of a given project's latest ruleset.


```solidity
function currentApprovalStatusForLatestRulesetOf(uint256 projectId) external view override returns (JBApprovalStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check the approval status of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBApprovalStatus`|The project's current approval status.|


### currentOf

The ruleset that is currently active for the specified project.

*If a current ruleset of the project is not found, returns an empty ruleset with all properties set to 0.*


```solidity
function currentOf(uint256 projectId) external view override returns (JBRuleset memory ruleset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the current ruleset of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The project's current ruleset.|


### getRulesetOf

Get the ruleset struct for a given `rulesetId` and `projectId`.


```solidity
function getRulesetOf(uint256 projectId, uint256 rulesetId) external view override returns (JBRuleset memory ruleset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to which the ruleset belongs.|
|`rulesetId`|`uint256`|The ID of the ruleset to get the struct of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The ruleset struct.|


### latestQueuedOf

The latest ruleset queued for a project. Returns the ruleset's struct and its current approval status.

*Returns struct and status for the ruleset initialized furthest in the future (at the end of the ruleset
queue).*


```solidity
function latestQueuedOf(uint256 projectId)
    external
    view
    override
    returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the latest queued ruleset of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The project's latest queued ruleset's struct.|
|`approvalStatus`|`JBApprovalStatus`|The approval hook's status for the ruleset.|


### upcomingOf

The ruleset that's up next for a project.

*If an upcoming ruleset is not found for the project, returns an empty ruleset with all properties set to 0.*


```solidity
function upcomingOf(uint256 projectId) external view override returns (JBRuleset memory ruleset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the upcoming ruleset of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The struct for the project's upcoming ruleset.|


### deriveCycleNumberFrom

The cycle number of the next ruleset given the specified ruleset.

*Each time a ruleset starts, whether it was queued or cycled over, the cycle number is incremented by 1.*


```solidity
function deriveCycleNumberFrom(
    uint256 baseRulesetCycleNumber,
    uint256 baseRulesetStart,
    uint256 baseRulesetDuration,
    uint256 start
)
    public
    pure
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseRulesetCycleNumber`|`uint256`|The cycle number of the base ruleset.|
|`baseRulesetStart`|`uint256`|The start time of the base ruleset.|
|`baseRulesetDuration`|`uint256`|The duration of the base ruleset.|
|`start`|`uint256`|The start time of the ruleset to derive a cycle number for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The ruleset's cycle number.|


### deriveStartFrom

The date that is the nearest multiple of the base ruleset's duration from the start of the next cycle.


```solidity
function deriveStartFrom(
    uint256 baseRulesetStart,
    uint256 baseRulesetDuration,
    uint256 mustStartAtOrAfter
)
    public
    pure
    returns (uint256 start);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`baseRulesetStart`|`uint256`|The start time of the base ruleset.|
|`baseRulesetDuration`|`uint256`|The duration of the base ruleset.|
|`mustStartAtOrAfter`|`uint256`|The earliest time the next ruleset can start. The ruleset cannot start before this timestamp.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`start`|`uint256`|The next start time.|


### deriveWeightFrom

The accumulated weight change since the specified ruleset.


```solidity
function deriveWeightFrom(
    uint256 projectId,
    uint256 baseRulesetStart,
    uint256 baseRulesetDuration,
    uint256 baseRulesetWeight,
    uint256 baseRulesetWeightCutPercent,
    uint256 baseRulesetCacheId,
    uint256 start
)
    public
    view
    returns (uint256 weight);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to which the ruleset weights apply.|
|`baseRulesetStart`|`uint256`|The start time of the base ruleset.|
|`baseRulesetDuration`|`uint256`|The duration of the base ruleset.|
|`baseRulesetWeight`|`uint256`|The weight of the base ruleset.|
|`baseRulesetWeightCutPercent`|`uint256`|The weight cut percent of the base ruleset.|
|`baseRulesetCacheId`|`uint256`|The ID of the ruleset to base the calculation on (the previous ruleset).|
|`start`|`uint256`|The start time of the ruleset to derive a weight for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`weight`|`uint256`|The derived weight, as a fixed point number with 18 decimals.|


### _approvalStatusOf

The approval status of a given project and ruleset struct according to the relevant approval hook.


```solidity
function _approvalStatusOf(uint256 projectId, JBRuleset memory ruleset) internal view returns (JBApprovalStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project that the ruleset belongs to.|
|`ruleset`|`JBRuleset`|The ruleset to get an approval flag for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBApprovalStatus`|The approval status of the project's ruleset.|


### _approvalStatusOf

The approval status of a given ruleset (ID) for a given project (ID).


```solidity
function _approvalStatusOf(
    uint256 projectId,
    uint256 rulesetId,
    uint256 start,
    uint256 approvalHookRulesetId
)
    internal
    view
    returns (JBApprovalStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project the ruleset belongs to.|
|`rulesetId`|`uint256`|The ID of the ruleset to get the approval status of.|
|`start`|`uint256`|The start time of the ruleset to get the approval status of.|
|`approvalHookRulesetId`|`uint256`|The ID of the ruleset with the approval hook that should be checked against.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBApprovalStatus`|The approval status of the project.|


### _currentlyApprovableRulesetIdOf

The ID of the ruleset which has started and hasn't expired yet, whether or not it has been approved, for
a given project. If approved, this is the active ruleset.

*A value of 0 is returned if no ruleset was found.*

*Assumes the project has a latest ruleset.*


```solidity
function _currentlyApprovableRulesetIdOf(uint256 projectId) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check for a currently approvable ruleset.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The ID of a currently approvable ruleset if one exists, or 0 if one doesn't exist.|


### _getStructFor

Unpack a ruleset's packed stored values into an easy-to-work-with ruleset struct.


```solidity
function _getStructFor(uint256 projectId, uint256 rulesetId) internal view returns (JBRuleset memory ruleset);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project the ruleset belongs to.|
|`rulesetId`|`uint256`|The ID of the ruleset to get the full struct for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|A ruleset struct.|


### _simulateCycledRulesetBasedOn

A simulated view of the ruleset that would be created if the provided one cycled over (if the project
doesn't queue a new ruleset).

*Returns an empty ruleset if a ruleset can't be simulated based on the provided one.*

*Assumes a simulated ruleset will never be based on a ruleset with a duration of 0.*


```solidity
function _simulateCycledRulesetBasedOn(
    uint256 projectId,
    JBRuleset memory baseRuleset,
    bool allowMidRuleset
)
    internal
    view
    returns (JBRuleset memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project of the ruleset.|
|`baseRuleset`|`JBRuleset`|The ruleset that the simulated ruleset should be based on.|
|`allowMidRuleset`|`bool`|A flag indicating if the simulated ruleset is allowed to already be mid ruleset.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBRuleset`|A simulated ruleset struct: the next ruleset by default. This will be overwritten if a new ruleset is queued for the project.|


### _upcomingApprovableRulesetIdOf

The ruleset up next for a project, if one exists, whether or not that ruleset has been approved.

*A value of 0 is returned if no ruleset was found.*

*Assumes the project has a `latestRulesetIdOf` value.*


```solidity
function _upcomingApprovableRulesetIdOf(uint256 projectId) internal view returns (uint256 rulesetId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check for an upcoming approvable ruleset.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rulesetId`|`uint256`|The `rulesetId` of the upcoming approvable ruleset if one exists, or 0 if one doesn't exist.|


### queueFor

Queues the upcoming approvable ruleset for the specified project.

*Only a project's current controller can queue its rulesets.*


```solidity
function queueFor(
    uint256 projectId,
    uint256 duration,
    uint256 weight,
    uint256 weightCutPercent,
    IJBRulesetApprovalHook approvalHook,
    uint256 metadata,
    uint256 mustStartAtOrAfter
)
    external
    override
    onlyControllerOf(projectId)
    returns (JBRuleset memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to queue the ruleset for.|
|`duration`|`uint256`|The number of seconds the ruleset lasts for, after which a new ruleset starts. - A `duration` of 0 means this ruleset will remain active until the project owner queues a new ruleset. That new ruleset will start immediately. - A ruleset with a non-zero `duration` applies until the duration ends – any newly queued rulesets will be *queued* to take effect afterwards. - If a duration ends and no new rulesets are queued, the ruleset rolls over to a new ruleset with the same rules (except for a new `start` timestamp and a cut `weight`).|
|`weight`|`uint256`|A fixed point number with 18 decimals that contracts can use to base arbitrary calculations on. Payment terminals generally use this to determine how many tokens should be minted when the project is paid.|
|`weightCutPercent`|`uint256`|A fraction (out of `JBConstants.MAX_WEIGHT_CUT_PERCENT`) to reduce the next ruleset's `weight` by. - If a ruleset specifies a non-zero `weight`, the `weightCutPercent` does not apply. - If the `weightCutPercent` is 0, the `weight` stays the same. - If the `weightCutPercent` is 10% of `JBConstants.MAX_WEIGHT_CUT_PERCENT`, next ruleset's `weight` will be 90% of the current one.|
|`approvalHook`|`IJBRulesetApprovalHook`|A contract which dictates whether a proposed ruleset should be accepted or rejected. It can be used to constrain a project owner's ability to change ruleset parameters over time.|
|`metadata`|`uint256`|Arbitrary extra data to associate with this ruleset. This metadata is not used by `JBRulesets`.|
|`mustStartAtOrAfter`|`uint256`|The earliest time the ruleset can start. The ruleset cannot start before this timestamp.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBRuleset`|The struct of the new ruleset.|


### updateRulesetWeightCache

Cache the value of the ruleset weight.


```solidity
function updateRulesetWeightCache(uint256 projectId) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project having its ruleset weight cached.|


### _configureIntrinsicPropertiesFor

Updates the latest ruleset for this project if it exists. If there is no ruleset, initializes one.


```solidity
function _configureIntrinsicPropertiesFor(
    uint256 projectId,
    uint256 rulesetId,
    uint256 weight,
    uint256 mustStartAtOrAfter
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to update the latest ruleset for.|
|`rulesetId`|`uint256`|The timestamp of when the ruleset was queued.|
|`weight`|`uint256`|The weight to store in the queued ruleset.|
|`mustStartAtOrAfter`|`uint256`|The earliest time the ruleset can start. The ruleset cannot start before this timestamp.|


### _initializeRulesetFor

Initializes a ruleset with the specified properties.


```solidity
function _initializeRulesetFor(
    uint256 projectId,
    JBRuleset memory baseRuleset,
    uint256 rulesetId,
    uint256 mustStartAtOrAfter,
    uint256 weight
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to initialize the ruleset for.|
|`baseRuleset`|`JBRuleset`|The ruleset struct to base the newly initialized one on.|
|`rulesetId`|`uint256`|The `rulesetId` for the ruleset being initialized.|
|`mustStartAtOrAfter`|`uint256`|The earliest time the ruleset can start. The ruleset cannot start before this timestamp.|
|`weight`|`uint256`|The weight to give the newly initialized ruleset.|


### _packAndStoreIntrinsicPropertiesOf

Efficiently stores the provided intrinsic properties of a ruleset.


```solidity
function _packAndStoreIntrinsicPropertiesOf(
    uint256 rulesetId,
    uint256 projectId,
    uint256 rulesetCycleNumber,
    uint256 weight,
    uint256 basedOnId,
    uint256 start
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`rulesetId`|`uint256`|The `rulesetId` of the ruleset to pack and store for.|
|`projectId`|`uint256`|The ID of the project the ruleset belongs to.|
|`rulesetCycleNumber`|`uint256`|The cycle number of the ruleset.|
|`weight`|`uint256`|The weight of the ruleset.|
|`basedOnId`|`uint256`|The `rulesetId` of the ruleset this ruleset was based on.|
|`start`|`uint256`|The start time of this ruleset.|


## Errors
### JBRulesets_InvalidWeightCutPercent

```solidity
error JBRulesets_InvalidWeightCutPercent(uint256 percent);
```

### JBRulesets_InvalidRulesetApprovalHook

```solidity
error JBRulesets_InvalidRulesetApprovalHook(IJBRulesetApprovalHook hook);
```

### JBRulesets_InvalidRulesetDuration

```solidity
error JBRulesets_InvalidRulesetDuration(uint256 duration, uint256 limit);
```

### JBRulesets_InvalidRulesetEndTime

```solidity
error JBRulesets_InvalidRulesetEndTime(uint256 timestamp, uint256 limit);
```

### JBRulesets_InvalidWeight

```solidity
error JBRulesets_InvalidWeight(uint256 weight, uint256 limit);
```

