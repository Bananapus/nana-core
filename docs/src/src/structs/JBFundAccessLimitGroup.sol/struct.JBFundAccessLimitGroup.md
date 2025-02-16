# JBFundAccessLimitGroup
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBFundAccessLimitGroup.sol)

*Payout limit example: if the `amount` is 5, the `currency` is 1 (USD), and the terminal's token is ETH, then
the project can pay out 5 USD worth of ETH during a ruleset.*

*Surplus allowance example: if the `amount` is 5, the `currency` is 1 (USD), and the terminal's token is ETH,
then the project can pay out 5 USD worth of ETH from its surplus during a ruleset. A project's surplus is its
balance minus its current combined payout limit.*

*If a project has multiple payout limits or surplus allowances, they are all available. They can all be used
during a single ruleset.*

*The payout limits' and surplus allowances' fixed point amounts have the same number of decimals as the
terminal.*

**Notes:**
- member: terminal The terminal that the payout limits and surplus allowances apply to.

- member: token The token that the payout limits and surplus allowances apply to within the `terminal`.

- member: payoutLimits An array of payout limits. The payout limits cumulatively dictate the maximum value of
`token`s a project can pay out from its balance in a terminal during a ruleset. Each payout limit can have a unique
currency and amount.

- member: surplusAllowances An array of surplus allowances. The surplus allowances cumulatively dictates the
maximum value of `token`s a project can pay out from its surplus (balance less payouts) in a terminal during a
ruleset. Each surplus allowance can have a unique currency and amount.


```solidity
struct JBFundAccessLimitGroup {
    address terminal;
    address token;
    JBCurrencyAmount[] payoutLimits;
    JBCurrencyAmount[] surplusAllowances;
}
```

