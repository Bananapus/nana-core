# JBFee
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBFee.sol)

**Notes:**
- member: amount The total amount the fee was taken from, as a fixed point number with the same number of
decimals as the terminal in which this struct was created.

- member: beneficiary The address that will receive the tokens that are minted as a result of the fee payment.

- member: unlockTimestamp The timestamp at which the fee is unlocked and can be processed.


```solidity
struct JBFee {
    uint256 amount;
    address beneficiary;
    uint48 unlockTimestamp;
}
```

