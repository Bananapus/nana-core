// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member token The token the payment was made in.
/// @custom:member value The amount of tokens that was paid, as a fixed point number.
/// @custom:member decimals The number of decimals included in the value fixed point number.
/// @custom:member currency The expected currency of the value.
struct JBTokenAmount {
    address token;
    uint160 value;
    uint8 decimals;
    uint32 currency;
}
