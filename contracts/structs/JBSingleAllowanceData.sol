// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member sigDeadline deadline on the permit signature
/// @custom:member amount the maximum amount allowed to spend
/// @custom:member expiration timestamp at which a spender's token allowances become invalid
/// @custom:member nonce an incrementing value indexed per owner,token,and spender for each signature
/// @custom:member signature the signature over the permit data. Supports EOA signatures, compact signatures defined by EIP-2098, and contract signatures defined by EIP-1271
struct JBSingleAllowanceData {
  uint256 sigDeadline;
  uint160 amount;
  uint48 expiration;
  uint48 nonce;
  bytes signature;
}
