# JBAccountingContext
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBAccountingContext.sol)

**Notes:**
- member: token The address of the token that accounting is being done with.

- member: decimals The number of decimals expected in that token's fixed point accounting.

- member: currency The currency that the token is priced in terms of. By convention, this is
`uint32(uint160(tokenAddress))` for tokens, or a constant ID from e.g. `JBCurrencyIds` for other currencies.


```solidity
struct JBAccountingContext {
    address token;
    uint8 decimals;
    uint32 currency;
}
```

