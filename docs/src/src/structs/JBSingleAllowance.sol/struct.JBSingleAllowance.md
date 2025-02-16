# JBSingleAllowance
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBSingleAllowance.sol)

**Notes:**
- member: sigDeadline Deadline on the permit signature.

- member: amount The maximum amount allowed to spend.

- member: expiration Timestamp at which a spender's token allowances become invalid.

- member: nonce An incrementing value indexed per owner,token,and spender for each signature.

- member: signature The signature over the permit data. Supports EOA signatures, compact signatures defined by
EIP-2098, and contract signatures defined by EIP-1271.


```solidity
struct JBSingleAllowance {
    uint256 sigDeadline;
    uint160 amount;
    uint48 expiration;
    uint48 nonce;
    bytes signature;
}
```

