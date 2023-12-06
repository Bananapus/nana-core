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
        uint256 indexed projectId,
        address beneficiary,
        uint256 amount,
        uint256 amountPaidOut,
        uint256 fee,
        uint256 beneficiaryDistributionAmount,
        address caller
    );

    event SendPayoutToSplit(
        uint256 indexed projectId,
        uint256 indexed domain,
        uint256 indexed group,
        JBSplit split,
        uint256 amount,
        uint256 netAmount,
        address caller
    );

    event UseAllowance(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint256 indexed projectId,
        address beneficiary,
        uint256 amount,
        uint256 amountPaidOut,
        uint256 netAmountPaidOut,
        string memo,
        address caller
    );

    event PayoutReverted(
        uint256 indexed projectId, JBSplit split, uint256 amount, bytes reason, address caller
    );

    function sendPayoutsOf(
        uint256 projectId,
        address token,
        uint256 amount,
        uint256 currency,
        uint256 minReturnedTokens
    ) external returns (uint256 netLeftoverPayoutAmount);

    function useAllowanceOf(
        uint256 projectId,
        address token,
        uint256 amount,
        uint256 currency,
        uint256 minReturnedTokens,
        address payable beneficiary,
        string calldata memo
    ) external returns (uint256 netAmountPaidOut);
}
