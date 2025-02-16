# JBController
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBController.sol)

**Inherits:**
[JBPermissioned](/src/abstract/JBPermissioned.sol/abstract.JBPermissioned.md), ERC2771Context, [IJBController](/src/interfaces/IJBController.sol/interface.IJBController.md), [IJBMigratable](/src/interfaces/IJBMigratable.sol/interface.IJBMigratable.md)

`JBController` coordinates rulesets and project tokens, and is the entry point for most operations related
to rulesets and project tokens.


## State Variables
### DIRECTORY
The directory of terminals and controllers for projects.


```solidity
IJBDirectory public immutable override DIRECTORY;
```


### FUND_ACCESS_LIMITS
A contract that stores fund access limits for each project.


```solidity
IJBFundAccessLimits public immutable override FUND_ACCESS_LIMITS;
```


### PRICES
A contract that stores prices for each project.


```solidity
IJBPrices public immutable override PRICES;
```


### PROJECTS
Mints ERC-721s that represent project ownership and transfers.


```solidity
IJBProjects public immutable override PROJECTS;
```


### RULESETS
The contract storing and managing project rulesets.


```solidity
IJBRulesets public immutable override RULESETS;
```


### SPLITS
The contract that stores splits for each project.


```solidity
IJBSplits public immutable override SPLITS;
```


### TOKENS
The contract that manages token minting and burning.


```solidity
IJBTokens public immutable override TOKENS;
```


### pendingReservedTokenBalanceOf
A project's unrealized reserved token balance (i.e. reserved tokens which haven't been sent out to the
reserved token split group yet).


```solidity
mapping(uint256 projectId => uint256) public override pendingReservedTokenBalanceOf;
```


### uriOf
The metadata URI for each project. This is typically an IPFS hash, optionally with an `ipfs://` prefix.


```solidity
mapping(uint256 projectId => string) public override uriOf;
```


## Functions
### constructor


```solidity
constructor(
    IJBDirectory directory,
    IJBFundAccessLimits fundAccessLimits,
    IJBPermissions permissions,
    IJBPrices prices,
    IJBProjects projects,
    IJBRulesets rulesets,
    IJBSplits splits,
    IJBTokens tokens,
    address trustedForwarder
)
    JBPermissioned(permissions)
    ERC2771Context(trustedForwarder);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`directory`|`IJBDirectory`|A contract storing directories of terminals and controllers for each project.|
|`fundAccessLimits`|`IJBFundAccessLimits`|A contract that stores fund access limits for each project.|
|`permissions`|`IJBPermissions`|A contract storing permissions.|
|`prices`|`IJBPrices`|A contract that stores prices for each project.|
|`projects`|`IJBProjects`|A contract which mints ERC-721s that represent project ownership and transfers.|
|`rulesets`|`IJBRulesets`|A contract storing and managing project rulesets.|
|`splits`|`IJBSplits`|A contract that stores splits for each project.|
|`tokens`|`IJBTokens`|A contract that manages token minting and burning.|
|`trustedForwarder`|`address`|The trusted forwarder for the ERC2771Context.|


### allRulesetsOf

Get an array of a project's rulesets (with metadata) up to a maximum array size, sorted from latest to
earliest.


```solidity
function allRulesetsOf(
    uint256 projectId,
    uint256 startingId,
    uint256 size
)
    external
    view
    override
    returns (JBRulesetWithMetadata[] memory rulesets);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the rulesets of.|
|`startingId`|`uint256`|The ID of the ruleset to begin with. This will be the latest ruleset in the result. If the `startingId` is 0, passed, the project's latest ruleset will be used.|
|`size`|`uint256`|The maximum number of rulesets to return.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rulesets`|`JBRulesetWithMetadata[]`|The array of rulesets with their metadata.|


### currentRulesetOf

A project's currently active ruleset and its metadata.


```solidity
function currentRulesetOf(uint256 projectId)
    external
    view
    override
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the current ruleset of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The current ruleset's struct.|
|`metadata`|`JBRulesetMetadata`|The current ruleset's metadata.|


### getRulesetOf

Get the `JBRuleset` and `JBRulesetMetadata` corresponding to the specified `rulesetId`.


```solidity
function getRulesetOf(
    uint256 projectId,
    uint256 rulesetId
)
    external
    view
    override
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project the ruleset belongs to.|
|`rulesetId`|`uint256`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The ruleset's struct.|
|`metadata`|`JBRulesetMetadata`|The ruleset's metadata.|


### latestQueuedRulesetOf

Gets the latest ruleset queued for a project, its approval status, and its metadata.

*The 'latest queued ruleset' is the ruleset initialized furthest in the future (at the end of the ruleset
queue).*


```solidity
function latestQueuedRulesetOf(uint256 projectId)
    external
    view
    override
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata, JBApprovalStatus approvalStatus);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the latest ruleset of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The struct for the project's latest queued ruleset.|
|`metadata`|`JBRulesetMetadata`|The ruleset's metadata.|
|`approvalStatus`|`JBApprovalStatus`|The ruleset's approval status.|


### setTerminalsAllowed

Check whether the project's terminals can currently be set.


```solidity
function setTerminalsAllowed(uint256 projectId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A `bool` which is true if the project allows terminals to be set.|


### setControllerAllowed

Check whether the project's controller can currently be set.


```solidity
function setControllerAllowed(uint256 projectId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A `bool` which is true if the project allows controllers to be set.|


### totalTokenSupplyWithReservedTokensOf

Gets the a project token's total supply, including pending reserved tokens.


```solidity
function totalTokenSupplyWithReservedTokensOf(uint256 projectId) external view override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the total token supply of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The total supply of the project's token, including pending reserved tokens.|


### upcomingRulesetOf

A project's next ruleset along with its metadata.

*If an upcoming ruleset isn't found, returns an empty ruleset with all properties set to 0.*


```solidity
function upcomingRulesetOf(uint256 projectId)
    external
    view
    override
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the next ruleset of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ruleset`|`JBRuleset`|The upcoming ruleset's struct.|
|`metadata`|`JBRulesetMetadata`|The upcoming ruleset's metadata.|


### supportsInterface

Indicates whether this contract adheres to the specified interface.

*See [IERC165-supportsInterface](/src/JBProjects.sol/contract.JBProjects.md#supportsinterface).*


```solidity
function supportsInterface(bytes4 interfaceId) public pure override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|The ID of the interface to check for adherence to.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating if the provided interface ID is supported.|


### _contextSuffixLength

*`ERC-2771` specifies the context as being a single address (20 bytes).*


```solidity
function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256);
```

### _currentRulesetOf

The project's current ruleset.


```solidity
function _currentRulesetOf(uint256 projectId) internal view returns (JBRuleset memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBRuleset`|The project's current ruleset.|


### _isTerminalOf

Indicates whether the provided address is a terminal for the project.


```solidity
function _isTerminalOf(uint256 projectId, address terminal) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|
|`terminal`|`address`|The address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating if the provided address is a terminal for the project.|


### _hasDataHookMintPermissionFor

Indicates whether the provided address has mint permission for the project byway of the data hook.


```solidity
function _hasDataHookMintPermissionFor(
    uint256 projectId,
    JBRuleset memory ruleset,
    address addrs
)
    internal
    view
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|
|`ruleset`|`JBRuleset`|The ruleset to check.|
|`addrs`|`address`|The address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating if the provided address has mint permission for the project.|


### _msgData

The calldata. Preferred to use over `msg.data`.


```solidity
function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`|calldata The `msg.data` of this call.|


### _msgSender

The message's sender. Preferred to use over `msg.sender`.


```solidity
function _msgSender() internal view override(ERC2771Context, Context) returns (address sender);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`sender`|`address`|The address which sent this call.|


### _upcomingRulesetOf

The project's upcoming ruleset.


```solidity
function _upcomingRulesetOf(uint256 projectId) internal view returns (JBRuleset memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBRuleset`|The project's upcoming ruleset.|


### addPriceFeed

Add a price feed for a project.

*Can only be called by the project's owner or an address with the owner's permission to `ADD_PRICE_FEED`.*


```solidity
function addPriceFeed(
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
|`projectId`|`uint256`|The ID of the project to add the feed for.|
|`pricingCurrency`|`uint256`|The currency the feed's output price is in terms of.|
|`unitCurrency`|`uint256`|The currency being priced by the feed.|
|`feed`|`IJBPriceFeed`|The address of the price feed to add.|


### burnTokensOf

Burns a project's tokens or credits from the specific holder's balance.

*Can only be called by the holder, an address with the holder's permission to `BURN_TOKENS`, or a project's
terminal.*


```solidity
function burnTokensOf(address holder, uint256 projectId, uint256 tokenCount, string calldata memo) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address whose tokens are being burned.|
|`projectId`|`uint256`|The ID of the project whose tokens are being burned.|
|`tokenCount`|`uint256`|The number of tokens to burn.|
|`memo`|`string`|A memo to pass along to the emitted event.|


### claimTokensFor

Redeem credits to claim tokens into a `beneficiary`'s account.

*Can only be called by the credit holder or an address with the holder's permission to `CLAIM_TOKENS`.*


```solidity
function claimTokensFor(address holder, uint256 projectId, uint256 tokenCount, address beneficiary) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to redeem credits from.|
|`projectId`|`uint256`|The ID of the project whose tokens are being claimed.|
|`tokenCount`|`uint256`|The number of tokens to claim.|
|`beneficiary`|`address`|The account the claimed tokens will go to.|


### deployERC20For

Deploys an ERC-20 token for a project. It will be used when claiming tokens (with credits).

*Deploys the project's ERC-20 contract.*

*Can only be called by the project's owner or an address with the owner's permission to `DEPLOY_ERC20`.*


```solidity
function deployERC20For(
    uint256 projectId,
    string calldata name,
    string calldata symbol,
    bytes32 salt
)
    external
    override
    returns (IJBToken token);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to deploy the ERC-20 for.|
|`name`|`string`|The ERC-20's name.|
|`symbol`|`string`|The ERC-20's symbol.|
|`salt`|`bytes32`|The salt used for ERC-1167 clone deployment. Pass a non-zero salt for deterministic deployment based on `msg.sender` and the `TOKEN` implementation address.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`token`|`IJBToken`|The address of the token that was deployed.|


### executePayReservedTokenToTerminal

When a project receives reserved tokens, if it has a terminal for the token, this is used to pay the
terminal.

*Can only be called by this controller.*


```solidity
function executePayReservedTokenToTerminal(
    IJBTerminal terminal,
    uint256 projectId,
    IJBToken token,
    uint256 splitTokenCount,
    address beneficiary,
    bytes calldata metadata
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`terminal`|`IJBTerminal`|The terminal to pay.|
|`projectId`|`uint256`|The ID of the project being paid.|
|`token`|`IJBToken`|The token being paid with.|
|`splitTokenCount`|`uint256`|The number of tokens being paid.|
|`beneficiary`|`address`|The payment's beneficiary.|
|`metadata`|`bytes`|The pay metadata sent to the terminal.|


### launchProjectFor

Creates a project.

*This will mint the project's ERC-721 to the `owner`'s address, queue the specified rulesets, and set up the
specified splits and terminals. Each operation within this transaction can be done in sequence separately.*

*Anyone can deploy a project to any `owner`'s address.*


```solidity
function launchProjectFor(
    address owner,
    string calldata projectUri,
    JBRulesetConfig[] calldata rulesetConfigurations,
    JBTerminalConfig[] calldata terminalConfigurations,
    string calldata memo
)
    external
    override
    returns (uint256 projectId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner`|`address`|The project's owner. The project ERC-721 will be minted to this address.|
|`projectUri`|`string`|The project's metadata URI. This is typically an IPFS hash, optionally with the `ipfs://` prefix. This can be updated by the project's owner.|
|`rulesetConfigurations`|`JBRulesetConfig[]`|The rulesets to queue.|
|`terminalConfigurations`|`JBTerminalConfig[]`|The terminals to set up for the project.|
|`memo`|`string`|A memo to pass along to the emitted event.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The project's ID.|


### launchRulesetsFor

Queue a project's initial rulesets and set up terminals for it. Projects which already have rulesets
should use `queueRulesetsOf(...)`.

*Each operation within this transaction can be done in sequence separately.*

*Can only be called by the project's owner or an address with the owner's permission to `QUEUE_RULESETS`.*


```solidity
function launchRulesetsFor(
    uint256 projectId,
    JBRulesetConfig[] calldata rulesetConfigurations,
    JBTerminalConfig[] calldata terminalConfigurations,
    string calldata memo
)
    external
    override
    returns (uint256 rulesetId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to launch rulesets for.|
|`rulesetConfigurations`|`JBRulesetConfig[]`|The rulesets to queue.|
|`terminalConfigurations`|`JBTerminalConfig[]`|The terminals to set up.|
|`memo`|`string`|A memo to pass along to the emitted event.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rulesetId`|`uint256`|The ID of the last successfully queued ruleset.|


### migrate

Migrate a project from this controller to another one.

*Can only be called by the directory.*


```solidity
function migrate(uint256 projectId, IERC165 to) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to migrate.|
|`to`|`IERC165`|The controller to migrate the project to.|


### mintTokensOf

Add new project tokens or credits to the specified beneficiary's balance. Optionally, reserve a portion
according to the ruleset's reserved percent.

*Can only be called by the project's owner, an address with the owner's permission to `MINT_TOKENS`, one of
the project's terminals, or the project's data hook.*

*If the ruleset's metadata has `allowOwnerMinting` set to `false`, this function can only be called by the
project's terminals or data hook.*


```solidity
function mintTokensOf(
    uint256 projectId,
    uint256 tokenCount,
    address beneficiary,
    string calldata memo,
    bool useReservedPercent
)
    external
    override
    returns (uint256 beneficiaryTokenCount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project whose tokens are being minted.|
|`tokenCount`|`uint256`|The number of tokens to mint, including any reserved tokens.|
|`beneficiary`|`address`|The address which will receive the (non-reserved) tokens.|
|`memo`|`string`|A memo to pass along to the emitted event.|
|`useReservedPercent`|`bool`|Whether to apply the ruleset's reserved percent.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`beneficiaryTokenCount`|`uint256`|The number of tokens minted for the `beneficiary`.|


### queueRulesetsOf

Add one or more rulesets to the end of a project's ruleset queue. Rulesets take effect after the
previous ruleset in the queue ends, and only if they are approved by the previous ruleset's approval hook.

*Can only be called by the project's owner or an address with the owner's permission to `QUEUE_RULESETS`.*


```solidity
function queueRulesetsOf(
    uint256 projectId,
    JBRulesetConfig[] calldata rulesetConfigurations,
    string calldata memo
)
    external
    override
    returns (uint256 rulesetId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to queue rulesets for.|
|`rulesetConfigurations`|`JBRulesetConfig[]`|The rulesets to queue.|
|`memo`|`string`|A memo to pass along to the emitted event.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rulesetId`|`uint256`|The ID of the last ruleset which was successfully queued.|


### beforeReceiveMigrationFrom

Prepares this controller to receive a project being migrated from another controller.

*This controller should not be the project's controller yet.*


```solidity
function beforeReceiveMigrationFrom(IERC165 from, uint256 projectId) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`IERC165`|The controller being migrated from.|
|`projectId`|`uint256`|The ID of the project that will migrate to this controller.|


### sendReservedTokensToSplitsOf

Sends a project's pending reserved tokens to its reserved token splits.

*If the project has no reserved token splits, or if they don't add up to 100%, leftover tokens are sent to
the project's owner.*


```solidity
function sendReservedTokensToSplitsOf(uint256 projectId) external override returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to send reserved tokens for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The amount of reserved tokens minted and sent.|


### setSplitGroupsOf

Sets a project's split groups. The new split groups must include any current splits which are locked.

*Can only be called by the project's owner or an address with the owner's permission to `SET_SPLIT_GROUPS`.*


```solidity
function setSplitGroupsOf(
    uint256 projectId,
    uint256 rulesetId,
    JBSplitGroup[] calldata splitGroups
)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to set the split groups of.|
|`rulesetId`|`uint256`|The ID of the ruleset the split groups should be active in. Use a `rulesetId` of 0 to set the default split groups, which are used when a ruleset has no splits set. If there are no default splits and no splits are set, all splits are sent to the project's owner.|
|`splitGroups`|`JBSplitGroup[]`|An array of split groups to set.|


### setTokenFor

Set a project's token. If the project's token is already set, this will revert.

*Can only be called by the project's owner or an address with the owner's permission to `SET_TOKEN`.*


```solidity
function setTokenFor(uint256 projectId, IJBToken token) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to set the token of.|
|`token`|`IJBToken`|The new token's address.|


### setUriOf

Set a project's metadata URI.

*This is typically an IPFS hash, optionally with an `ipfs://` prefix.*

*Can only be called by the project's owner or an address with the owner's permission to
`SET_PROJECT_URI`.*


```solidity
function setUriOf(uint256 projectId, string calldata uri) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to set the metadata URI of.|
|`uri`|`string`|The metadata URI to set.|


### transferCreditsFrom

Allows a credit holder to transfer credits to another address.

*Can only be called by the credit holder or an address with the holder's permission to `TRANSFER_CREDITS`.*


```solidity
function transferCreditsFrom(
    address holder,
    uint256 projectId,
    address recipient,
    uint256 creditCount
)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The address to transfer credits from.|
|`projectId`|`uint256`|The ID of the project whose credits are being transferred.|
|`recipient`|`address`|The address to transfer credits to.|
|`creditCount`|`uint256`|The number of credits to transfer.|


### _configureTerminals

Set up a project's terminals.


```solidity
function _configureTerminals(uint256 projectId, JBTerminalConfig[] calldata terminalConfigs) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to set up terminals for.|
|`terminalConfigs`|`JBTerminalConfig[]`|The terminals to set up.|


### _queueRulesets

Queues one or more rulesets and stores information pertinent to the configuration.


```solidity
function _queueRulesets(
    uint256 projectId,
    JBRulesetConfig[] calldata rulesetConfigurations
)
    internal
    returns (uint256 rulesetId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to queue rulesets for.|
|`rulesetConfigurations`|`JBRulesetConfig[]`|The rulesets being queued.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`rulesetId`|`uint256`|The ID of the last ruleset that was successfully queued.|


### _sendReservedTokensToSplitsOf

Sends pending reserved tokens to the project's reserved token splits.

*If the project has no reserved token splits, or if they don't add up to 100%, leftover tokens are sent to
the project's owner.*


```solidity
function _sendReservedTokensToSplitsOf(uint256 projectId) internal returns (uint256 tokenCount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to send reserved tokens for.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`tokenCount`|`uint256`|The amount of reserved tokens minted and sent.|


### _sendReservedTokensToSplitGroupOf

Send project tokens to a split group.

*This is used to send reserved tokens to the reserved token split group.*


```solidity
function _sendReservedTokensToSplitGroupOf(
    uint256 projectId,
    uint256 rulesetId,
    uint256 groupId,
    uint256 tokenCount,
    IJBToken token
)
    internal
    returns (uint256 leftoverTokenCount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project the splits belong to.|
|`rulesetId`|`uint256`|The ID of the split group's ruleset.|
|`groupId`|`uint256`|The ID of the split group.|
|`tokenCount`|`uint256`|The number of tokens to send.|
|`token`|`IJBToken`|The token to send.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`leftoverTokenCount`|`uint256`|If the split percents don't add up to 100%, the leftover amount is returned.|


### _sendTokens

Send tokens from this contract to a recipient.


```solidity
function _sendTokens(uint256 projectId, uint256 tokenCount, address recipient, IJBToken token) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project the tokens belong to.|
|`tokenCount`|`uint256`|The number of tokens to send.|
|`recipient`|`address`|The address to send the tokens to.|
|`token`|`IJBToken`|The token to send, if one exists|


## Errors
### JBController_AddingPriceFeedNotAllowed

```solidity
error JBController_AddingPriceFeedNotAllowed();
```

### JBController_CreditTransfersPaused

```solidity
error JBController_CreditTransfersPaused();
```

### JBController_InvalidCashOutTaxRate

```solidity
error JBController_InvalidCashOutTaxRate(uint256 rate, uint256 limit);
```

### JBController_InvalidReservedPercent

```solidity
error JBController_InvalidReservedPercent(uint256 percent, uint256 limit);
```

### JBController_MintNotAllowedAndNotTerminalOrHook

```solidity
error JBController_MintNotAllowedAndNotTerminalOrHook();
```

### JBController_NoReservedTokens

```solidity
error JBController_NoReservedTokens();
```

### JBController_OnlyDirectory

```solidity
error JBController_OnlyDirectory(address sender, IJBDirectory directory);
```

### JBController_RulesetsAlreadyLaunched

```solidity
error JBController_RulesetsAlreadyLaunched();
```

### JBController_RulesetsArrayEmpty

```solidity
error JBController_RulesetsArrayEmpty();
```

### JBController_RulesetSetTokenNotAllowed

```solidity
error JBController_RulesetSetTokenNotAllowed();
```

### JBController_ZeroTokensToBurn

```solidity
error JBController_ZeroTokensToBurn();
```

### JBController_ZeroTokensToMint

```solidity
error JBController_ZeroTokensToMint();
```

