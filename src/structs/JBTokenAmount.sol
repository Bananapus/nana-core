// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member token The token the payment was made in.
/// @custom:member value The amount of tokens that was paid, as a fixed point number.
/// @custom:member decimals The number of decimals included in the value fixed point number.
/// @custom:member currency The currency. By convention, this is `uint32(uint160(tokenAddress))` for tokens, or a
/// constant ID from e.g. `JBCurrencyIds` for other currencies.
struct JBTokenAmount {
    address token;
    uint256 value;
    uint256 decimals;
    uint256 currency;
}
