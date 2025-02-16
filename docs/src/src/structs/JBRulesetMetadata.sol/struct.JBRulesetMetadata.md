# JBRulesetMetadata
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBRulesetMetadata.sol)

**Notes:**
- member: reservedPercent The reserved percent of the ruleset. This number is a percentage calculated out of
`JBConstants.MAX_RESERVED_PERCENT`.

- member: cashOutTaxRate The cash out tax rate of the ruleset. This number is a percentage calculated out of
`JBConstants.MAX_CASH_OUT_TAX_RATE`.

- member: baseCurrency The currency on which to base the ruleset's weight. By convention, this is
`uint32(uint160(tokenAddress))` for tokens, or a constant ID from e.g. `JBCurrencyIds` for other currencies.

- member: pausePay A flag indicating if the pay functionality should be paused during the ruleset.

- member: pauseCreditTransfers A flag indicating if the project token transfer functionality should be paused
during the funding cycle.

- member: allowOwnerMinting A flag indicating if the project owner or an operator with the `MINT_TOKENS`
permission from the owner should be allowed to mint project tokens on demand during this ruleset.

- member: allowTerminalMigration A flag indicating if migrating terminals should be allowed during this
ruleset.

- member: allowSetTerminals A flag indicating if a project's terminals can be added or removed.

- member: allowSetController A flag indicating if a project's controller can be changed.

- member: allowAddAccountingContext A flag indicating if a project can add new accounting contexts for its
terminals to use.

- member: allowAddPriceFeed A flag indicating if a project can add new price feeds to calculate exchange rates
between its tokens.

- member: ownerMustSendPayouts A flag indicating if privileged payout distribution should be
enforced, otherwise payouts can be distributed by anyone.

- member: holdFees A flag indicating if fees should be held during this ruleset.

- member: useTotalSurplusForCashOuts A flag indicating if cash outs should use the project's balance held
in all terminals instead of the project's local terminal balance from which the cash out is being fulfilled.

- member: useDataHookForPay A flag indicating if the data hook should be used for pay transactions during this
ruleset.

- member: useDataHookForCashOut A flag indicating if the data hook should be used for cash out transactions
during
this ruleset.

- member: dataHook The data hook to use during this ruleset.

- member: metadata Metadata of the metadata, only the 14 least significant bits can be used, the 2 most
significant bits are disregarded.


```solidity
struct JBRulesetMetadata {
    uint16 reservedPercent;
    uint16 cashOutTaxRate;
    uint32 baseCurrency;
    bool pausePay;
    bool pauseCreditTransfers;
    bool allowOwnerMinting;
    bool allowSetCustomToken;
    bool allowTerminalMigration;
    bool allowSetTerminals;
    bool allowSetController;
    bool allowAddAccountingContext;
    bool allowAddPriceFeed;
    bool ownerMustSendPayouts;
    bool holdFees;
    bool useTotalSurplusForCashOuts;
    bool useDataHookForPay;
    bool useDataHookForCashOut;
    address dataHook;
    uint16 metadata;
}
```

