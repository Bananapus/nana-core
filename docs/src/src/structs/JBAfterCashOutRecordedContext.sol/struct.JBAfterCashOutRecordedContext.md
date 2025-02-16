# JBAfterCashOutRecordedContext
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBAfterCashOutRecordedContext.sol)

**Notes:**
- member: holder The holder of the tokens being cashed out.

- member: projectId The ID of the project being cashed out from.

- member: rulesetId The ID of the ruleset the cash out is being made during.

- member: cashOutCount The number of project tokens being cashed out.

- member: cashOutTaxRate The current ruleset's cash out tax rate.

- member: reclaimedAmount The token amount being reclaimed from the project's terminal balance. Includes the
token being
reclaimed, the value, the number of decimals included, and the currency of the amount.

- member: forwardedAmount The token amount being forwarded to the cash out hook. Includes the token
being forwarded, the value, the number of decimals included, and the currency of the amount.

- member: beneficiary The address the reclaimed amount will be sent to.

- member: hookMetadata Extra data specified by the data hook, which is sent to the cash out hook.

- member: cashOutMetadata Extra data specified by the account cashing out, which is sent to the cash out hook.


```solidity
struct JBAfterCashOutRecordedContext {
    address holder;
    uint256 projectId;
    uint256 rulesetId;
    uint256 cashOutCount;
    JBTokenAmount reclaimedAmount;
    JBTokenAmount forwardedAmount;
    uint256 cashOutTaxRate;
    address payable beneficiary;
    bytes hookMetadata;
    bytes cashOutMetadata;
}
```

