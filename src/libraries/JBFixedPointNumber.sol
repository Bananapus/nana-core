// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library JBFixedPointNumber {
    function adjustDecimals(uint160 value, uint8 decimals, uint8 targetDecimals) internal pure returns (uint160) {
        // If decimals need adjusting, multiply or divide the price by the decimal adjuster to get the normalized
        // result.
        if (targetDecimals == decimals) return value;
        else if (targetDecimals > decimals) return uint160(value * 10 ** (targetDecimals - decimals));
        else return uint160(value / 10 ** (decimals - targetDecimals));
    }
}
