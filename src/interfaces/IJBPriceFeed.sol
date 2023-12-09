// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBPriceFeed {
    function currentUnitPrice(uint8 targetDecimals) external view returns (uint160);
}
