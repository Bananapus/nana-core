// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member token The token the payment was made in.
/// @custom:member decimals The number of decimals included in the value fixed point number.
/// @custom:member currency The currency. By convention, this is `uint32(uint160(tokenAddress))` for tokens, or a
/// constant ID from e.g. `JBCurrencyIds` for other currencies.
/// @custom:member value The amount of tokens that was paid, as a fixed point number.
struct JBTokenAmount {
    address token;
    uint8 decimals;
    uint32 currency;
    uint256 value;
}
