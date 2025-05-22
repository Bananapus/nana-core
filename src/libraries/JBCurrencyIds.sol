// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library JBCurrencyIds {
    uint32 public constant ETH = 1;
    uint32 public constant USD = 3; // Skip 2, a botched price feed was deployed on 2.
}
