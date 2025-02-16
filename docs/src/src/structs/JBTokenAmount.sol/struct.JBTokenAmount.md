# JBTokenAmount
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBTokenAmount.sol)

**Notes:**
- member: token The token the payment was made in.

- member: decimals The number of decimals included in the value fixed point number.

- member: currency The currency. By convention, this is `uint32(uint160(tokenAddress))` for tokens, or a
constant ID from e.g. `JBCurrencyIds` for other currencies.

- member: value The amount of tokens that was paid, as a fixed point number.


```solidity
struct JBTokenAmount {
    address token;
    uint8 decimals;
    uint32 currency;
    uint256 value;
}
```

