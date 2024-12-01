// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Global constants used across Juicebox contracts.
library JBConstants {
    /// @notice Each chain's native token address in Juicebox is represented by
    /// 0x000000000000000000000000000000000000EEEe.
    address public constant NATIVE_TOKEN = address(0x000000000000000000000000000000000000EEEe);
    uint16 public constant MAX_RESERVED_PERCENT = 10_000;
    uint16 public constant MAX_CASH_OUT_TAX_RATE = 10_000;
    uint32 public constant MAX_WEIGHT_CUT_PERCENT = 1_000_000_000;
    uint32 public constant SPLITS_TOTAL_PERCENT = 1_000_000_000;
    uint16 public constant MAX_FEE = 1000;
}
