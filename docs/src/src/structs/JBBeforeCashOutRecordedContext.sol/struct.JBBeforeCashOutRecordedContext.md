# JBBeforeCashOutRecordedContext
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBBeforeCashOutRecordedContext.sol)

Context sent from the terminal to the ruleset's data hook upon cash out.

**Notes:**
- member: terminal The terminal that is facilitating the cash out.

- member: holder The holder of the tokens being cashed out.

- member: projectId The ID of the project whose tokens are being cashed out.

- member: rulesetId The ID of the ruleset the cash out is being made during.

- member: cashOutCount The number of tokens being cashed out, as a fixed point number with 18 decimals.

- member: totalSupply The total token supply being used for the calculation, as a fixed point number with 18
decimals.

- member: surplus The surplus amount used for the calculation, as a fixed point number with 18 decimals.
Includes the token of the surplus, the surplus value, the number of decimals
included, and the currency of the surplus.

- member: useTotalSurplus If surplus across all of a project's terminals is being used when making cash outs.

- member: cashOutTaxRate The cash out tax rate of the ruleset the cash out is being made during.

- member: metadata Extra data provided by the casher.


```solidity
struct JBBeforeCashOutRecordedContext {
    address terminal;
    address holder;
    uint256 projectId;
    uint256 rulesetId;
    uint256 cashOutCount;
    uint256 totalSupply;
    JBTokenAmount surplus;
    bool useTotalSurplus;
    uint256 cashOutTaxRate;
    bytes metadata;
}
```

