# JBMultiTerminal
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/JBMultiTerminal.sol)

**Inherits:**
[JBPermissioned](/src/abstract/JBPermissioned.sol/abstract.JBPermissioned.md), ERC2771Context, [IJBMultiTerminal](/src/interfaces/IJBMultiTerminal.sol/interface.IJBMultiTerminal.md)

`JBMultiTerminal` manages native/ERC-20 payments, cash outs, and surplus allowance usage for any number of
projects. Terminals are the entry point for operations involving inflows and outflows of funds.


## State Variables
### FEE
This terminal's fee (as a fraction out of `JBConstants.MAX_FEE`).

*Fees are charged on payouts to addresses and surplus allowance usage, as well as cash outs while the
cash out tax rate is less than 100%.*


```solidity
uint256 public constant override FEE = 25;
```


### _FEE_BENEFICIARY_PROJECT_ID
Project ID #1 receives fees. It should be the first project launched during the deployment process.


```solidity
uint256 internal constant _FEE_BENEFICIARY_PROJECT_ID = 1;
```


### _FEE_HOLDING_SECONDS
The number of seconds fees can be held for.


```solidity
uint256 internal constant _FEE_HOLDING_SECONDS = 2_419_200;
```


### DIRECTORY
The directory of terminals and controllers for PROJECTS.


```solidity
IJBDirectory public immutable override DIRECTORY;
```


### FEELESS_ADDRESSES
The contract that stores addresses that shouldn't incur fees when being paid towards or from.


```solidity
IJBFeelessAddresses public immutable override FEELESS_ADDRESSES;
```


### PERMIT2
The permit2 utility.


```solidity
IPermit2 public immutable override PERMIT2;
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


### STORE
The contract that stores and manages the terminal's data.


```solidity
IJBTerminalStore public immutable override STORE;
```


### TOKENS
The contract storing and managing project rulesets.


```solidity
IJBTokens public immutable override TOKENS;
```


### _accountingContextForTokenOf
Context describing how a token is accounted for by a project.


```solidity
mapping(uint256 projectId => mapping(address token => JBAccountingContext)) internal _accountingContextForTokenOf;
```


### _accountingContextsOf
A list of tokens accepted by each project.


```solidity
mapping(uint256 projectId => JBAccountingContext[]) internal _accountingContextsOf;
```


### _heldFeesOf
Fees that are being held for each project.

*Projects can temporarily hold fees and unlock them later by adding funds to the project's balance.*

*Held fees can be processed at any time by this terminal's owner.*


```solidity
mapping(uint256 projectId => mapping(address token => JBFee[])) internal _heldFeesOf;
```


### _nextHeldFeeIndexOf
The next index to use when processing a next held fee.


```solidity
mapping(uint256 projectId => mapping(address token => uint256)) internal _nextHeldFeeIndexOf;
```


## Functions
### constructor


```solidity
constructor(
    IJBFeelessAddresses feelessAddresses,
    IJBPermissions permissions,
    IJBProjects projects,
    IJBSplits splits,
    IJBTerminalStore store,
    IJBTokens tokens,
    IPermit2 permit2,
    address trustedForwarder
)
    JBPermissioned(permissions)
    ERC2771Context(trustedForwarder);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`feelessAddresses`|`IJBFeelessAddresses`|A contract that stores addresses that shouldn't incur fees when being paid towards or from.|
|`permissions`|`IJBPermissions`|A contract storing permissions.|
|`projects`|`IJBProjects`|A contract which mints ERC-721s that represent project ownership and transfers.|
|`splits`|`IJBSplits`|A contract that stores splits for each project.|
|`store`|`IJBTerminalStore`|A contract that stores the terminal's data.|
|`tokens`|`IJBTokens`||
|`permit2`|`IPermit2`|A permit2 utility.|
|`trustedForwarder`|`address`|A trusted forwarder of transactions to this contract.|


### accountingContextForTokenOf

A project's accounting context for a token.

*See the `JBAccountingContext` struct for more information.*


```solidity
function accountingContextForTokenOf(
    uint256 projectId,
    address token
)
    external
    view
    override
    returns (JBAccountingContext memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get token accounting context of.|
|`token`|`address`|The token to check the accounting context of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBAccountingContext`|The token's accounting context for the token.|


### accountingContextsOf

The tokens accepted by a project.


```solidity
function accountingContextsOf(uint256 projectId) external view override returns (JBAccountingContext[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the accepted tokens of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`JBAccountingContext[]`|tokenContexts The accounting contexts of the accepted tokens.|


### currentSurplusOf

Gets the total current surplus amount in this terminal for a project, in terms of a given currency.

*This total surplus only includes tokens that the project accepts (as returned by
`accountingContextsOf(...)`).*


```solidity
function currentSurplusOf(
    uint256 projectId,
    JBAccountingContext[] memory accountingContexts,
    uint256 decimals,
    uint256 currency
)
    external
    view
    override
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the current total surplus of.|
|`accountingContexts`|`JBAccountingContext[]`|The accounting contexts to use to calculate the surplus. Pass an empty array to use all of the project's accounting contexts.|
|`decimals`|`uint256`|The number of decimals to include in the fixed point returned value.|
|`currency`|`uint256`|The currency to express the returned value in terms of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|The current surplus amount the project has in this terminal, in terms of `currency` and with the specified number of decimals.|


### heldFeesOf

Fees that are being held for a project.

*Projects can temporarily hold fees and unlock them later by adding funds to the project's balance.*

*Held fees can be processed at any time by this terminal's owner.*


```solidity
function heldFeesOf(
    uint256 projectId,
    address token,
    uint256 count
)
    external
    view
    override
    returns (JBFee[] memory heldFees);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project that is holding fees.|
|`token`|`address`|The token that the fees are held in.|
|`count`|`uint256`||


### supportsInterface

Indicates whether this contract adheres to the specified interface.

*See [IERC165-supportsInterface](/src/JBController.sol/contract.JBController.md#supportsinterface).*


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


### _balanceOf

Checks this terminal's balance of a specific token.


```solidity
function _balanceOf(address token) internal view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|The address of the token to get this terminal's balance of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|This terminal's balance.|


### _contextSuffixLength

*`ERC-2771` specifies the context as being a single address (20 bytes).*


```solidity
function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256);
```

### _controllerOf

Returns the current controller of a project.


```solidity
function _controllerOf(uint256 projectId) internal view returns (IJBController);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the controller of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IJBController`|controller The project's controller.|


### _isFeeless

Returns a flag indicating if interacting with an address should not incur fees.


```solidity
function _isFeeless(address addr) internal view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|A flag indicating if the address should not incur fees.|


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


### _ownerOf

The owner of a project.


```solidity
function _ownerOf(uint256 projectId) internal view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the owner of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The owner of the project.|


### _primaryTerminalOf

The primary terminal of a project for a token.


```solidity
function _primaryTerminalOf(uint256 projectId, address token) internal view returns (IJBTerminal);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to get the primary terminal of.|
|`token`|`address`|The token to get the primary terminal of.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IJBTerminal`|The primary terminal of the project for the token.|


### addAccountingContextsFor

Adds accounting contexts for a project to this terminal so the project can begin accepting the tokens in
those contexts.

*Only a project's owner, an operator with the `ADD_ACCOUNTING_CONTEXTS` permission from that owner, or a
project's controller can add accounting contexts for the project.*


```solidity
function addAccountingContextsFor(
    uint256 projectId,
    JBAccountingContext[] calldata accountingContexts
)
    external
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project having to add accounting contexts for.|
|`accountingContexts`|`JBAccountingContext[]`|The accounting contexts to add.|


### addToBalanceOf

Adds funds to a project's balance without minting tokens.

*Adding to balance can unlock held fees if `shouldUnlockHeldFees` is true.*


```solidity
function addToBalanceOf(
    uint256 projectId,
    address token,
    uint256 amount,
    bool shouldReturnHeldFees,
    string calldata memo,
    bytes calldata metadata
)
    external
    payable
    override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to add funds to the balance of.|
|`token`|`address`|The token being added to the balance.|
|`amount`|`uint256`|The amount of tokens to add to the balance, as a fixed point number with the same number of decimals as this terminal. If this is a native token terminal, this is ignored and `msg.value` is used instead.|
|`shouldReturnHeldFees`|`bool`|A flag indicating if held fees should be returned based on the amount being added.|
|`memo`|`string`|A memo to pass along to the emitted event.|
|`metadata`|`bytes`|Extra data to pass along to the emitted event.|


### cashOutTokensOf

Holders can cash out a project's tokens to reclaim some of that project's surplus tokens, or to trigger
rules determined by the current ruleset's data hook and cash out hook.

*Only a token's holder or an operator with the `CASH_OUT_TOKENS` permission from that holder can cash out
those tokens.*


```solidity
function cashOutTokensOf(
    address holder,
    uint256 projectId,
    uint256 cashOutCount,
    address tokenToReclaim,
    uint256 minTokensReclaimed,
    address payable beneficiary,
    bytes calldata metadata
)
    external
    override
    returns (uint256 reclaimAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The account whose tokens are being cashed out.|
|`projectId`|`uint256`|The ID of the project the project tokens belong to.|
|`cashOutCount`|`uint256`|The number of project tokens to cash out, as a fixed point number with 18 decimals.|
|`tokenToReclaim`|`address`|The token being reclaimed.|
|`minTokensReclaimed`|`uint256`|The minimum number of terminal tokens expected in return, as a fixed point number with the same number of decimals as this terminal. If the amount of tokens minted for the beneficiary would be less than this amount, the cash out is reverted.|
|`beneficiary`|`address payable`|The address to send the cashed out terminal tokens to, and to pass along to the ruleset's data hook and cash out hook if applicable.|
|`metadata`|`bytes`|Bytes to send along to the emitted event, as well as the data hook and cash out hook if applicable.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reclaimAmount`|`uint256`|The amount of terminal tokens that the project tokens were cashed out for, as a fixed point number with 18 decimals.|


### executePayout

Executes a payout to a split.

*Only accepts calls from this terminal itself.*


```solidity
function executePayout(
    JBSplit calldata split,
    uint256 projectId,
    address token,
    uint256 amount,
    address originalMessageSender
)
    external
    returns (uint256 netPayoutAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`split`|`JBSplit`|The split to pay.|
|`projectId`|`uint256`|The ID of the project the split belongs to.|
|`token`|`address`|The address of the token being paid to the split.|
|`amount`|`uint256`|The total amount being paid to the split, as a fixed point number with the same number of decimals as this terminal.|
|`originalMessageSender`|`address`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`netPayoutAmount`|`uint256`|The amount sent to the split after subtracting fees.|


### executeProcessFee

Process a specified amount of fees for a project.

*Only accepts calls from this terminal itself.*


```solidity
function executeProcessFee(
    uint256 projectId,
    address token,
    uint256 amount,
    address beneficiary,
    IJBTerminal feeTerminal
)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project paying the fee.|
|`token`|`address`|The token the fee is being paid in.|
|`amount`|`uint256`|The fee amount, as a fixed point number with 18 decimals.|
|`beneficiary`|`address`|The address to mint tokens to (from the project which receives fees), and pass along to the ruleset's data hook and pay hook if applicable.|
|`feeTerminal`|`IJBTerminal`|The terminal that'll receive the fees.|


### executeTransferTo

Transfer funds to an address.

*Only accepts calls from this terminal itself.*


```solidity
function executeTransferTo(address payable addr, address token, uint256 amount) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address payable`|The address to transfer funds to.|
|`token`|`address`|The token to transfer.|
|`amount`|`uint256`|The amount of tokens to transfer.|


### migrateBalanceOf

Migrate a project's funds and operations to a new terminal that accepts the same token type.

*Only a project's owner or an operator with the `MIGRATE_TERMINAL` permission from that owner can migrate
the project's terminal.*


```solidity
function migrateBalanceOf(
    uint256 projectId,
    address token,
    IJBTerminal to
)
    external
    override
    returns (uint256 balance);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project being migrated.|
|`token`|`address`|The address of the token being migrated.|
|`to`|`IJBTerminal`|The terminal contract being migrated to, which will receive the project's funds and operations.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`balance`|`uint256`|The amount of funds that were migrated, as a fixed point number with the same amount of decimals as this terminal.|


### pay

Pay a project with tokens.


```solidity
function pay(
    uint256 projectId,
    address token,
    uint256 amount,
    address beneficiary,
    uint256 minReturnedTokens,
    string calldata memo,
    bytes calldata metadata
)
    external
    payable
    override
    returns (uint256 beneficiaryTokenCount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project being paid.|
|`token`|`address`|The token being paid.|
|`amount`|`uint256`|The amount of terminal tokens being received, as a fixed point number with the same number of decimals as this terminal. If this terminal's token is native, this is ignored and `msg.value` is used in its place.|
|`beneficiary`|`address`|The address to mint tokens to, and pass along to the ruleset's data hook and pay hook if applicable.|
|`minReturnedTokens`|`uint256`|The minimum number of project tokens expected in return for this payment, as a fixed point number with the same number of decimals as this terminal. If the amount of tokens minted for the beneficiary would be less than this amount, the payment is reverted.|
|`memo`|`string`|A memo to pass along to the emitted event.|
|`metadata`|`bytes`|Bytes to pass along to the emitted event, as well as the data hook and pay hook if applicable.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`beneficiaryTokenCount`|`uint256`|The number of tokens minted to the beneficiary, as a fixed point number with 18 decimals.|


### processHeldFeesOf

Process any fees that are being held for the project.


```solidity
function processHeldFeesOf(uint256 projectId, address token, uint256 count) external override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to process held fees for.|
|`token`|`address`|The token to process held fees for.|
|`count`|`uint256`|The number of fees to process.|


### sendPayoutsOf

Sends payouts to a project's current payout split group, according to its ruleset, up to its current
payout limit.

*If the percentages of the splits in the project's payout split group do not add up to 100%, the remainder
is sent to the project's owner.*

*Anyone can send payouts on a project's behalf. Projects can include a wildcard split (a split with no
`hook`, `projectId`, or `beneficiary`) to send funds to the `_msgSender()` which calls this function. This can
be used to incentivize calling this function.*

*payouts sent to addresses which aren't feeless incur the protocol fee.*

*Payouts a projects don't incur fees if its terminal is feeless.*


```solidity
function sendPayoutsOf(
    uint256 projectId,
    address token,
    uint256 amount,
    uint256 currency,
    uint256 minTokensPaidOut
)
    external
    override
    returns (uint256 amountPaidOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project having its payouts sent.|
|`token`|`address`|The token being sent.|
|`amount`|`uint256`|The total number of terminal tokens to send, as a fixed point number with same number of decimals as this terminal.|
|`currency`|`uint256`|The expected currency of the payouts being sent. Must match the currency of one of the project's current ruleset's payout limits.|
|`minTokensPaidOut`|`uint256`|The minimum number of terminal tokens that the `amount` should be worth (if expressed in terms of this terminal's currency), as a fixed point number with the same number of decimals as this terminal. If the amount of tokens paid out would be less than this amount, the send is reverted.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountPaidOut`|`uint256`|The total amount paid out.|


### useAllowanceOf

Allows a project to pay out funds from its surplus up to the current surplus allowance.

*Only a project's owner or an operator with the `USE_ALLOWANCE` permission from that owner can use the
surplus allowance.*

*Incurs the protocol fee unless the caller is a feeless address.*


```solidity
function useAllowanceOf(
    uint256 projectId,
    address token,
    uint256 amount,
    uint256 currency,
    uint256 minTokensPaidOut,
    address payable beneficiary,
    address payable feeBeneficiary,
    string calldata memo
)
    external
    override
    returns (uint256 netAmountPaidOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to use the surplus allowance of.|
|`token`|`address`|The token being paid out from the surplus.|
|`amount`|`uint256`|The amount of terminal tokens to use from the project's current surplus allowance, as a fixed point number with the same amount of decimals as this terminal.|
|`currency`|`uint256`|The expected currency of the amount being paid out. Must match the currency of one of the project's current ruleset's surplus allowances.|
|`minTokensPaidOut`|`uint256`|The minimum number of terminal tokens that should be returned from the surplus allowance (excluding fees), as a fixed point number with 18 decimals. If the amount of surplus used would be less than this amount, the transaction is reverted.|
|`beneficiary`|`address payable`|The address to send the surplus funds to.|
|`feeBeneficiary`|`address payable`|The address to send the tokens resulting from paying the fee.|
|`memo`|`string`|A memo to pass along to the emitted event.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`netAmountPaidOut`|`uint256`|The number of tokens that were sent to the beneficiary, as a fixed point number with the same amount of decimals as the terminal.|


### _acceptFundsFor

Accepts an incoming token.


```solidity
function _acceptFundsFor(
    uint256 projectId,
    address token,
    uint256 amount,
    bytes calldata metadata
)
    internal
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project that the transfer is being accepted for.|
|`token`|`address`|The token being accepted.|
|`amount`|`uint256`|The number of tokens being accepted.|
|`metadata`|`bytes`|The metadata in which permit2 context is provided.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount The number of tokens which have been accepted.|


### _addToBalanceOf

Adds funds to a project's balance without minting tokens.


```solidity
function _addToBalanceOf(
    uint256 projectId,
    address token,
    uint256 amount,
    bool shouldReturnHeldFees,
    string memory memo,
    bytes memory metadata
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to add funds to the balance of.|
|`token`|`address`|The address of the token being added to the project's balance.|
|`amount`|`uint256`|The amount of tokens to add as a fixed point number with the same number of decimals as this terminal. If this is a native token terminal, this is ignored and `msg.value` is used instead.|
|`shouldReturnHeldFees`|`bool`|A flag indicating if held fees should be returned based on the amount being added.|
|`memo`|`string`|A memo to pass along to the emitted event.|
|`metadata`|`bytes`|Extra data to pass along to the emitted event.|


### _beforeTransferTo

Logic to be triggered before transferring tokens from this terminal.


```solidity
function _beforeTransferTo(address to, address token, uint256 amount) internal returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address the transfer is going to.|
|`token`|`address`|The token being transferred.|
|`amount`|`uint256`|The number of tokens being transferred, as a fixed point number with the same number of decimals as this terminal.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|payValue The value to attach to the transaction being sent.|


### _cashOutTokensOf

Holders can cash out their tokens to reclaim some of a project's surplus, or to trigger rules determined
by
the project's current ruleset's data hook.

*Only a token holder or an operator with the `CASH_OUT_TOKENS` permission from that holder can cash out
those
tokens.*


```solidity
function _cashOutTokensOf(
    address holder,
    uint256 projectId,
    uint256 cashOutCount,
    address tokenToReclaim,
    address payable beneficiary,
    bytes memory metadata
)
    internal
    returns (uint256 reclaimAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`holder`|`address`|The account cashing out tokens.|
|`projectId`|`uint256`|The ID of the project whose tokens are being cashed out.|
|`cashOutCount`|`uint256`|The number of project tokens to cash out, as a fixed point number with 18 decimals.|
|`tokenToReclaim`|`address`|The address of the token which is being cashed out.|
|`beneficiary`|`address payable`|The address to send the reclaimed terminal tokens to.|
|`metadata`|`bytes`|Bytes to send along to the emitted event, as well as the data hook and cash out hook if applicable.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`reclaimAmount`|`uint256`|The number of terminal tokens reclaimed for the `beneficiary`, as a fixed point number with 18 decimals.|


### _efficientAddToBalance

Fund a project either by calling this terminal's internal `addToBalance` function or by calling the
recipient
terminal's `addToBalance` function.


```solidity
function _efficientAddToBalance(
    IJBTerminal terminal,
    uint256 projectId,
    address token,
    uint256 amount,
    bytes memory metadata
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`terminal`|`IJBTerminal`|The terminal on which the project is expecting to receive funds.|
|`projectId`|`uint256`|The ID of the project being funded.|
|`token`|`address`|The token being used.|
|`amount`|`uint256`|The amount being funded, as a fixed point number with the amount of decimals that the terminal's accounting context specifies.|
|`metadata`|`bytes`|Additional metadata to include with the payment.|


### _efficientPay

Pay a project either by calling this terminal's internal `pay` function or by calling the recipient
terminal's `pay` function.


```solidity
function _efficientPay(
    IJBTerminal terminal,
    uint256 projectId,
    address token,
    uint256 amount,
    address beneficiary,
    bytes memory metadata
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`terminal`|`IJBTerminal`|The terminal on which the project is expecting to receive payments.|
|`projectId`|`uint256`|The ID of the project being paid.|
|`token`|`address`|The token being paid in.|
|`amount`|`uint256`|The amount being paid, as a fixed point number with the amount of decimals that the terminal's accounting context specifies.|
|`beneficiary`|`address`|The address to receive any platform tokens minted.|
|`metadata`|`bytes`|Additional metadata to include with the payment.|


### _fulfillPayHookSpecificationsFor

Fulfills a list of pay hook specifications.


```solidity
function _fulfillPayHookSpecificationsFor(
    uint256 projectId,
    JBPayHookSpecification[] memory specifications,
    JBTokenAmount memory tokenAmount,
    address payer,
    JBRuleset memory ruleset,
    address beneficiary,
    uint256 newlyIssuedTokenCount,
    bytes memory metadata
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project being paid.|
|`specifications`|`JBPayHookSpecification[]`|The pay hook specifications to be fulfilled.|
|`tokenAmount`|`JBTokenAmount`|The amount of tokens that the project was paid.|
|`payer`|`address`|The address that sent the payment.|
|`ruleset`|`JBRuleset`|The ruleset the payment is being accepted during.|
|`beneficiary`|`address`|The address which will receive any tokens that the payment yields.|
|`newlyIssuedTokenCount`|`uint256`|The amount of tokens that are being issued and sent to the beneificary.|
|`metadata`|`bytes`|Bytes to send along to the emitted event and pay hooks as applicable.|


### _fulfillCashOutHookSpecificationsFor

Fulfills a list of cash out hook specifications.


```solidity
function _fulfillCashOutHookSpecificationsFor(
    uint256 projectId,
    JBTokenAmount memory beneficiaryReclaimAmount,
    address holder,
    uint256 cashOutCount,
    bytes memory metadata,
    JBRuleset memory ruleset,
    uint256 cashOutTaxRate,
    address payable beneficiary,
    JBCashOutHookSpecification[] memory specifications
)
    internal
    returns (uint256 amountEligibleForFees);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project being cashed out from.|
|`beneficiaryReclaimAmount`|`JBTokenAmount`|The number of tokens that are being cashed out from the project.|
|`holder`|`address`|The address that holds the tokens being cashed out.|
|`cashOutCount`|`uint256`|The number of tokens being cashed out.|
|`metadata`|`bytes`|Bytes to send along to the emitted event and cash out hooks as applicable.|
|`ruleset`|`JBRuleset`|The ruleset the cash out is being made during as a `JBRuleset` struct.|
|`cashOutTaxRate`|`uint256`|The cash out tax rate influencing the reclaim amount.|
|`beneficiary`|`address payable`|The address which will receive any terminal tokens that are cashed out.|
|`specifications`|`JBCashOutHookSpecification[]`|The hook specifications being fulfilled.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountEligibleForFees`|`uint256`|The amount of funds which were allocated to cash out hooks and are eligible for fees.|


### _pay

Pay a project with tokens.


```solidity
function _pay(
    uint256 projectId,
    address token,
    uint256 amount,
    address payer,
    address beneficiary,
    string memory memo,
    bytes memory metadata
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project being paid.|
|`token`|`address`|The address of the token which the project is being paid with.|
|`amount`|`uint256`|The amount of terminal tokens being received, as a fixed point number with the same number of decimals as this terminal. If this terminal's token is the native token, `amount` is ignored and `msg.value` is used in its place.|
|`payer`|`address`|The address making the payment.|
|`beneficiary`|`address`|The address to mint tokens to, and pass along to the ruleset's data hook and pay hook if applicable.|
|`memo`|`string`|A memo to pass along to the emitted event.|
|`metadata`|`bytes`|Bytes to send along to the emitted event, as well as the data hook and pay hook if applicable.|


### _processFee

Process a fee of the specified amount from a project.


```solidity
function _processFee(
    uint256 projectId,
    address token,
    uint256 amount,
    address beneficiary,
    IJBTerminal feeTerminal,
    bool wasHeld
)
    internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project paying the fee.|
|`token`|`address`|The token the fee is being paid in.|
|`amount`|`uint256`|The fee amount, as a fixed point number with 18 decimals.|
|`beneficiary`|`address`|The address which will receive any platform tokens minted.|
|`feeTerminal`|`IJBTerminal`|The terminal that'll receive the fee.|
|`wasHeld`|`bool`|A flag indicating if the fee being processed was being held by this terminal.|


### _recordAddedBalanceFor

Records an added balance for a project.


```solidity
function _recordAddedBalanceFor(uint256 projectId, address token, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to record the added balance for.|
|`token`|`address`|The token to record the added balance for.|
|`amount`|`uint256`|The amount of the token to record, as a fixed point number with the same number of decimals as this terminal.|


### _returnHeldFees

Returns held fees to the project who paid them based on the specified amount.


```solidity
function _returnHeldFees(uint256 projectId, address token, uint256 amount) internal returns (uint256 returnedFees);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The project held fees are being returned to.|
|`token`|`address`|The token that the held fees are in.|
|`amount`|`uint256`|The amount to base the calculation on, as a fixed point number with the same number of decimals as this terminal.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`returnedFees`|`uint256`|The amount of held fees that were returned, as a fixed point number with the same number of decimals as this terminal|


### _sendPayoutsOf

Sends payouts to a project's current payout split group, according to its ruleset, up to its current
payout limit.

*If the percentages of the splits in the project's payout split group do not add up to 100%, the remainder
is sent to the project's owner.*

*Anyone can send payouts on a project's behalf. Projects can include a wildcard split (a split with no
`hook`, `projectId`, or `beneficiary`) to send funds to the `_msgSender()` which calls this function. This can
be used to incentivize calling this function.*

*Payouts sent to addresses which aren't feeless incur the protocol fee.*


```solidity
function _sendPayoutsOf(
    uint256 projectId,
    address token,
    uint256 amount,
    uint256 currency
)
    internal
    returns (uint256 amountPaidOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to send the payouts of.|
|`token`|`address`|The token being paid out.|
|`amount`|`uint256`|The number of terminal tokens to pay out, as a fixed point number with same number of decimals as this terminal.|
|`currency`|`uint256`|The expected currency of the amount being paid out. Must match the currency of one of the project's current ruleset's payout limits.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountPaidOut`|`uint256`|The total amount that was paid out.|


### _sendPayoutToSplit

Sends a payout to a split.


```solidity
function _sendPayoutToSplit(
    JBSplit memory split,
    uint256 projectId,
    address token,
    uint256 amount
)
    internal
    returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`split`|`JBSplit`|The split to pay.|
|`projectId`|`uint256`|The ID of the project the split was specified by.|
|`token`|`address`|The address of the token being paid out.|
|`amount`|`uint256`|The total amount that the split is being paid, as a fixed point number with the same number of decimals as this terminal.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|netPayoutAmount The amount sent to the split after subtracting fees.|


### _sendPayoutsToSplitGroupOf

Sends payouts to the payout splits group specified in a project's ruleset.


```solidity
function _sendPayoutsToSplitGroupOf(
    uint256 projectId,
    address token,
    uint256 rulesetId,
    uint256 amount
)
    internal
    returns (uint256, uint256 amountEligibleForFees);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to send the payouts of.|
|`token`|`address`|The address of the token being paid out.|
|`rulesetId`|`uint256`|The ID of the ruleset of the split group being paid.|
|`amount`|`uint256`|The total amount being paid out, as a fixed point number with the same number of decimals as this terminal.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|amount The leftover amount (zero if the splits add up to 100%).|
|`amountEligibleForFees`|`uint256`|The total amount of funds which were paid out and are eligible for fees.|


### _takeFeeFrom

Takes a fee into the platform's project (with the `_FEE_BENEFICIARY_PROJECT_ID`).


```solidity
function _takeFeeFrom(
    uint256 projectId,
    address token,
    uint256 amount,
    address beneficiary,
    bool shouldHoldFees
)
    internal
    returns (uint256 feeAmount);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project paying the fee.|
|`token`|`address`|The address of the token that the fee is being paid in.|
|`amount`|`uint256`|The fee's token amount, as a fixed point number with 18 decimals.|
|`beneficiary`|`address`|The address to mint the platform's project's tokens for.|
|`shouldHoldFees`|`bool`|If fees should be tracked and held instead of being exercised immediately.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`feeAmount`|`uint256`|The amount of the fee taken.|


### _transferFrom

Transfers tokens.


```solidity
function _transferFrom(address from, address payable to, address token, uint256 amount) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address the transfer should originate from.|
|`to`|`address payable`|The address the transfer should go to.|
|`token`|`address`|The token being transfered.|
|`amount`|`uint256`|The number of tokens being transferred, as a fixed point number with the same number of decimals as this terminal.|


### _useAllowanceOf

Allows a project to send out funds from its surplus up to the current surplus allowance.

*Only a project's owner or an operator with the `USE_ALLOWANCE` permission from that owner can use the
surplus allowance.*

*Incurs the protocol fee unless the caller is a feeless address.*


```solidity
function _useAllowanceOf(
    uint256 projectId,
    address owner,
    address token,
    uint256 amount,
    uint256 currency,
    address payable beneficiary,
    address payable feeBeneficiary,
    string memory memo
)
    internal
    returns (uint256 netAmountPaidOut);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`projectId`|`uint256`|The ID of the project to use the surplus allowance of.|
|`owner`|`address`|The project's owner.|
|`token`|`address`|The token being paid out from the surplus.|
|`amount`|`uint256`|The amount of terminal tokens to use from the project's current surplus allowance, as a fixed point number with the same amount of decimals as this terminal.|
|`currency`|`uint256`|The expected currency of the amount being paid out. Must match the currency of one of the project's current ruleset's surplus allowances.|
|`beneficiary`|`address payable`|The address to send the funds to.|
|`feeBeneficiary`|`address payable`|The address to send the tokens resulting from paying the fee.|
|`memo`|`string`|A memo to pass along to the emitted event.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`netAmountPaidOut`|`uint256`|The amount of tokens paid out.|


## Errors
### JBMultiTerminal_AccountingContextAlreadySet

```solidity
error JBMultiTerminal_AccountingContextAlreadySet(address token);
```

### JBMultiTerminal_AddingAccountingContextNotAllowed

```solidity
error JBMultiTerminal_AddingAccountingContextNotAllowed();
```

### JBMultiTerminal_FeeTerminalNotFound

```solidity
error JBMultiTerminal_FeeTerminalNotFound();
```

### JBMultiTerminal_NoMsgValueAllowed

```solidity
error JBMultiTerminal_NoMsgValueAllowed(uint256 value);
```

### JBMultiTerminal_OverflowAlert

```solidity
error JBMultiTerminal_OverflowAlert(uint256 value, uint256 limit);
```

### JBMultiTerminal_PermitAllowanceNotEnough

```solidity
error JBMultiTerminal_PermitAllowanceNotEnough(uint256 amount, uint256 allowance);
```

### JBMultiTerminal_RecipientProjectTerminalNotFound

```solidity
error JBMultiTerminal_RecipientProjectTerminalNotFound(uint256 projectId, address token);
```

### JBMultiTerminal_SplitHookInvalid

```solidity
error JBMultiTerminal_SplitHookInvalid(IJBSplitHook hook);
```

### JBMultiTerminal_TerminalTokensIncompatible

```solidity
error JBMultiTerminal_TerminalTokensIncompatible();
```

### JBMultiTerminal_TokenNotAccepted

```solidity
error JBMultiTerminal_TokenNotAccepted(address token);
```

### JBMultiTerminal_UnderMinReturnedTokens

```solidity
error JBMultiTerminal_UnderMinReturnedTokens(uint256 count, uint256 min);
```

### JBMultiTerminal_UnderMinTokensPaidOut

```solidity
error JBMultiTerminal_UnderMinTokensPaidOut(uint256 amount, uint256 min);
```

### JBMultiTerminal_UnderMinTokensReclaimed

```solidity
error JBMultiTerminal_UnderMinTokensReclaimed(uint256 amount, uint256 min);
```

### JBMultiTerminal_ZeroAccountingContextDecimals

```solidity
error JBMultiTerminal_ZeroAccountingContextDecimals();
```

### JBMultiTerminal_ZeroAccountingContextCurrency

```solidity
error JBMultiTerminal_ZeroAccountingContextCurrency();
```

