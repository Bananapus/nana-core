// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member token The subject of the context.
/// @custom:member standard The standard of the token.
struct JBAccountingContextConfig {
    address token;
    uint8 standard;
}
