// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member amount The total amount the fee was taken from, as a fixed point number with the same number of
/// decimals as the terminal in which this struct was created.
/// @custom:member beneficiary The address that will receive the tokens that are minted as a result of the fee payment.
/// @custom:member unlockTimestamp The timestamp at which the fee is unlocked and can be processed.
struct JBFee {
    uint256 amount;
    address beneficiary;
    uint256 unlockTimestamp;
}
