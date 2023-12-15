// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member token The subject of the context.
/// @custom:member decimals The number of decimals expected in a token's fixed point accounting.
/// @custom:member currency The currency a token is accounting in.
/// @custom:member standard The standard of the token.
struct JBAccountingContext {
    address token;
    uint8 decimals;
    uint32 currency;
    uint8 standard;
}
