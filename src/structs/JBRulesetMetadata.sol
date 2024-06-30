// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member reservedRate The reserved rate of the ruleset. This number is a percentage calculated out of
/// `JBConstants.MAX_RESERVED_RATE`.
/// @custom:member redemptionRate The redemption rate of the ruleset. This number is a percentage calculated out of
/// `JBConstants.MAX_REDEMPTION_RATE`.
/// @custom:member baseCurrency The currency on which to base the ruleset's weight. By convention, this is
/// `uint32(uint160(tokenAddress))` for tokens, or a constant ID from e.g. `JBCurrencyIds` for other currencies.
/// @custom:member pausePay A flag indicating if the pay functionality should be paused during the ruleset.
/// @custom:member pauseCreditTransfers A flag indicating if the project token transfer functionality should be paused
/// during the funding cycle.
/// @custom:member allowOwnerMinting A flag indicating if the project owner or an operator with the `MINT_TOKENS`
/// permission from the owner should be allowed to mint project tokens on demand during this ruleset.
/// @custom:member allowTerminalMigration A flag indicating if migrating terminals should be allowed during this
/// ruleset.
/// @custom:member allowSetTerminals A flag indicating if a project's terminals can be added or removed.
/// @custom:member allowSetController A flag indicating if a project's controller can be changed.
/// @custom:member allowAddAccountingContext A flag indicating if a project can add new accounting contexts for its terminals to use.
/// @custom:member allowAddPriceFeed A flag indicating if a project can add new price feeds to calculate exchange rates between its tokens.
/// @custom:member ownerMustSendPayouts A flag indicating if privileged payout distribution should be
/// enforced, otherwise payouts can be distributed by anyone.
/// @custom:member holdFees A flag indicating if fees should be held during this ruleset.
/// @custom:member useTotalSurplusForRedemptions A flag indicating if redemptions should use the project's balance held
/// in all terminals instead of the project's local terminal balance from which the redemption is being fulfilled.
/// @custom:member useDataHookForPay A flag indicating if the data hook should be used for pay transactions during this
/// ruleset.
/// @custom:member useDataHookForRedeem A flag indicating if the data hook should be used for redeem transactions during
/// this ruleset.
/// @custom:member dataHook The data hook to use during this ruleset.
/// @custom:member metadata Metadata of the metadata, up to uint8 in size.
struct JBRulesetMetadata {
    uint256 reservedRate;
    uint256 redemptionRate;
    uint256 baseCurrency;
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
    bool useTotalSurplusForRedemptions;
    bool useDataHookForPay;
    bool useDataHookForRedeem;
    address dataHook;
    uint256 metadata;
}
