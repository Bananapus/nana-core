// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./IJBTerminal.sol";
import {JBSplit} from "../../structs/JBSplit.sol";
import {IJBSplits} from "../IJBSplits.sol";

/// @notice A terminal that can send payouts.
interface IJBPayoutTerminal is IJBTerminal {
    event SendPayouts(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint32 indexed projectId,
        address beneficiary,
        uint160 amount,
        uint160 amountPaidOut,
        uint160 fee,
        uint160 beneficiaryDistributionAmount,
        address caller
    );

    event SendPayoutToSplit(
        uint32 indexed projectId,
        uint56 indexed domain,
        uint160 indexed group,
        JBSplit split,
        uint160 amount,
        uint160 netAmount,
        address caller
    );

    event UseAllowance(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint32 indexed projectId,
        address beneficiary,
        uint160 amount,
        uint160 amountPaidOut,
        uint160 netAmountPaidOut,
        string memo,
        address caller
    );

    event PayoutReverted(uint32 indexed projectId, JBSplit split, uint160 amount, bytes reason, address caller);

    function sendPayoutsOf(
        uint32 projectId,
        address token,
        uint160 amount,
        uint32 currency,
        uint160 minReturnedTokens
    )
        external
        returns (uint160 netLeftoverPayoutAmount);

    function useAllowanceOf(
        uint32 projectId,
        address token,
        uint160 amount,
        uint32 currency,
        uint160 minReturnedTokens,
        address payable beneficiary,
        string calldata memo
    )
        external
        returns (uint160 netAmountPaidOut);
}
