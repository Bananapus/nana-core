// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member value The value of the amount.
/// @custom:member currency The currency of the value.
struct JBCurrencyAmount {
  uint256 value;
  uint256 currency;
}
