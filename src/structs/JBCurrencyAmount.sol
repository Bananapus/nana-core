// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member amount The amount of the currency.
/// @custom:member currency The currency. By convention, this is `uint32(uint160(tokenAddress))` for tokens, or a
/// constant ID from e.g. `JBCurrencyIds` for other currencies.
struct JBCurrencyAmount {
    uint224 amount;
    uint32 currency;
}
