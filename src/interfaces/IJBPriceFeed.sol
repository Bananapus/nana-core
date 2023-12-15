// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IJBPriceFeed {
    function currentUnitPrice(uint256 targetDecimals) external view returns (uint256);
}
