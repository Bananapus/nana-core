// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBSplitHook} from "./../interfaces/IJBSplitHook.sol";

/// @notice Splits are used to send a percentage of a total token amount to a specific contract, project, or address. Splits are used to send payouts and reserved tokens.
/// @dev 1. If a non-zero split hook contract is specified, this split's tokens are sent there along with this split's properties.
/// @dev 2. Otherwise, if a non-zero project ID is specified, this split's tokens are used to `pay` it through its terminal if possible, or sent to the project's owner if not. If this payment yields tokens, those go to the split's `beneficiary`.
/// @dev 3. Otherwise, this split's tokens are sent directly to the `beneficiary`.
/// @dev To summarize, this split's tokens are sent according to the following priority: `split hook` > `projectId` > `beneficiary`.
/// @custom:member preferAddToBalance If this split were to `pay` a project through its terminal, this flag indicates whether it should prefer using the terminal's `addToBalance` function instead.
/// @custom:member percent The percent of the total token amount that this split sends. This number is out of `JBConstants.SPLITS_TOTAL_PERCENT`.
/// @custom:member projectId The ID of a project to `pay`, if applicable. Resulting tokens will be routed to the `beneficiary`.
/// @custom:member beneficiary Receives this split's tokens if the `hook` and `projectId` are zero. If the `projectId` is specified, the `beneficiary` receives any project tokens minted by this split.
/// @custom:member lockedUntil The split cannot be changed until this timestamp. The `lockedUntil` timestamp can be increased while a split is locked. If `lockedUntil` is zero, this split can be changed at any time.
/// @custom:member hook A contract which will receive this split's tokens and properties, and can define custom behavior.
struct JBSplit {
    bool preferAddToBalance;
    uint256 percent;
    uint256 projectId;
    address payable beneficiary;
    uint256 lockedUntil;
    IJBSplitHook hook;
}
