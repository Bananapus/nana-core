// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member amount The amount of the currency.
/// @custom:member currency The currency's index in `JBCurrencyIds`.
struct JBCurrencyAmount {
    uint160 amount;
    uint32 currency;
}
