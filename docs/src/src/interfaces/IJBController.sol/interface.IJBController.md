# IJBController
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/interfaces/IJBController.sol)

**Inherits:**
IERC165, [IJBProjectUriRegistry](/src/interfaces/IJBProjectUriRegistry.sol/interface.IJBProjectUriRegistry.md), [IJBDirectoryAccessControl](/src/interfaces/IJBDirectoryAccessControl.sol/interface.IJBDirectoryAccessControl.md)


## Functions
### DIRECTORY


```solidity
function DIRECTORY() external view returns (IJBDirectory);
```

### FUND_ACCESS_LIMITS


```solidity
function FUND_ACCESS_LIMITS() external view returns (IJBFundAccessLimits);
```

### PRICES


```solidity
function PRICES() external view returns (IJBPrices);
```

### PROJECTS


```solidity
function PROJECTS() external view returns (IJBProjects);
```

### RULESETS


```solidity
function RULESETS() external view returns (IJBRulesets);
```

### SPLITS


```solidity
function SPLITS() external view returns (IJBSplits);
```

### TOKENS


```solidity
function TOKENS() external view returns (IJBTokens);
```

### allRulesetsOf


```solidity
function allRulesetsOf(
    uint256 projectId,
    uint256 startingId,
    uint256 size
)
    external
    view
    returns (JBRulesetWithMetadata[] memory rulesets);
```

### currentRulesetOf


```solidity
function currentRulesetOf(uint256 projectId)
    external
    view
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
```

### getRulesetOf


```solidity
function getRulesetOf(
    uint256 projectId,
    uint256 rulesetId
)
    external
    view
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
```

### latestQueuedRulesetOf


```solidity
function latestQueuedRulesetOf(uint256 projectId)
    external
    view
    returns (JBRuleset memory, JBRulesetMetadata memory metadata, JBApprovalStatus);
```

### pendingReservedTokenBalanceOf


```solidity
function pendingReservedTokenBalanceOf(uint256 projectId) external view returns (uint256);
```

### totalTokenSupplyWithReservedTokensOf


```solidity
function totalTokenSupplyWithReservedTokensOf(uint256 projectId) external view returns (uint256);
```

### upcomingRulesetOf


```solidity
function upcomingRulesetOf(uint256 projectId)
    external
    view
    returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata);
```

### addPriceFeed


```solidity
function addPriceFeed(uint256 projectId, uint256 pricingCurrency, uint256 unitCurrency, IJBPriceFeed feed) external;
```

### burnTokensOf


```solidity
function burnTokensOf(address holder, uint256 projectId, uint256 tokenCount, string calldata memo) external;
```

### claimTokensFor


```solidity
function claimTokensFor(address holder, uint256 projectId, uint256 tokenCount, address beneficiary) external;
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

### launchProjectFor


```solidity
function launchProjectFor(
    address owner,
    string calldata projectUri,
    JBRulesetConfig[] calldata rulesetConfigurations,
    JBTerminalConfig[] memory terminalConfigurations,
    string calldata memo
)
    external
    returns (uint256 projectId);
```

### launchRulesetsFor


```solidity
function launchRulesetsFor(
    uint256 projectId,
    JBRulesetConfig[] calldata rulesetConfigurations,
    JBTerminalConfig[] memory terminalConfigurations,
    string calldata memo
)
    external
    returns (uint256 rulesetId);
```

### mintTokensOf


```solidity
function mintTokensOf(
    uint256 projectId,
    uint256 tokenCount,
    address beneficiary,
    string calldata memo,
    bool useReservedPercent
)
    external
    returns (uint256 beneficiaryTokenCount);
```

### queueRulesetsOf


```solidity
function queueRulesetsOf(
    uint256 projectId,
    JBRulesetConfig[] calldata rulesetConfigurations,
    string calldata memo
)
    external
    returns (uint256 rulesetId);
```

### sendReservedTokensToSplitsOf


```solidity
function sendReservedTokensToSplitsOf(uint256 projectId) external returns (uint256);
```

### setSplitGroupsOf


```solidity
function setSplitGroupsOf(uint256 projectId, uint256 rulesetId, JBSplitGroup[] calldata splitGroups) external;
```

### setTokenFor


```solidity
function setTokenFor(uint256 projectId, IJBToken token) external;
```

### transferCreditsFrom


```solidity
function transferCreditsFrom(address holder, uint256 projectId, address recipient, uint256 creditCount) external;
```

## Events
### BurnTokens

```solidity
event BurnTokens(address indexed holder, uint256 indexed projectId, uint256 tokenCount, string memo, address caller);
```

### LaunchProject

```solidity
event LaunchProject(uint256 rulesetId, uint256 projectId, string projectUri, string memo, address caller);
```

### LaunchRulesets

```solidity
event LaunchRulesets(uint256 rulesetId, uint256 projectId, string memo, address caller);
```

### MintTokens

```solidity
event MintTokens(
    address indexed beneficiary,
    uint256 indexed projectId,
    uint256 tokenCount,
    uint256 beneficiaryTokenCount,
    string memo,
    uint256 reservedPercent,
    address caller
);
```

### PrepMigration

```solidity
event PrepMigration(uint256 indexed projectId, address from, address caller);
```

### QueueRulesets

```solidity
event QueueRulesets(uint256 rulesetId, uint256 projectId, string memo, address caller);
```

### ReservedDistributionReverted

```solidity
event ReservedDistributionReverted(
    uint256 indexed projectId, JBSplit split, uint256 tokenCount, bytes reason, address caller
);
```

### SendReservedTokensToSplit

```solidity
event SendReservedTokensToSplit(
    uint256 indexed projectId,
    uint256 indexed rulesetId,
    uint256 indexed groupId,
    JBSplit split,
    uint256 tokenCount,
    address caller
);
```

### SendReservedTokensToSplits

```solidity
event SendReservedTokensToSplits(
    uint256 indexed rulesetId,
    uint256 indexed rulesetCycleNumber,
    uint256 indexed projectId,
    address owner,
    uint256 tokenCount,
    uint256 leftoverAmount,
    address caller
);
```

### SetUri

```solidity
event SetUri(uint256 indexed projectId, string uri, address caller);
```

