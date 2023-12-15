// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library JBFixedPointNumber {
    function adjustDecimals(uint256 value, uint256 decimals, uint256 targetDecimals) internal pure returns (uint256) {
        // If decimals need adjusting, multiply or divide the price by the decimal adjuster to get the normalized
        // result.
        if (targetDecimals == decimals) return value;
        else if (targetDecimals > decimals) return value * 10 ** (targetDecimals - decimals);
        else return value / 10 ** (decimals - targetDecimals);
    }
}
