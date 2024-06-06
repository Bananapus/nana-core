// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member token The address of the token that accounting is being done with.
/// @custom:member decimals The number of decimals expected in that token's fixed point accounting.
/// @custom:member currency The currency that the token is priced in terms of. By convention, this is
/// `uint32(uint160(tokenAddress))` for tokens, or a constant ID from e.g. `JBCurrencyIds` for other currencies.
struct JBAccountingContext {
    address token;
    uint8 decimals;
    uint32 currency;
}
