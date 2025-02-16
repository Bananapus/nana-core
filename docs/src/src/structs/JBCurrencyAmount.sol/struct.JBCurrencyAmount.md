# JBCurrencyAmount
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBCurrencyAmount.sol)

**Notes:**
- member: amount The amount of the currency.

- member: currency The currency. By convention, this is `uint32(uint160(tokenAddress))` for tokens, or a
constant ID from e.g. `JBCurrencyIds` for other currencies.


```solidity
struct JBCurrencyAmount {
    uint224 amount;
    uint32 currency;
}
```

