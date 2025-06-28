// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member totalAmount The total amount of tokens to be vested.
/// @custom:member startTime The timestamp when the vesting starts.
struct JBVestingSchedule {
    uint256 totalAmount;
    uint256 startTime;
}
