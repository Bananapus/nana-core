// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBCashOutHook} from "./IJBCashOutHook.sol";
import {IJBTerminal} from "./IJBTerminal.sol";
import {JBAfterCashOutRecordedContext} from "../structs/JBAfterCashOutRecordedContext.sol";

/// @notice A terminal that can be cashed out from.
interface IJBCashOutTerminal is IJBTerminal {
    event HookAfterRecordCashOut(
        IJBCashOutHook indexed hook,
        JBAfterCashOutRecordedContext context,
        uint256 specificationAmount,
        uint256 fee,
        address caller
    );
    event CashOutTokens(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint256 indexed projectId,
        address holder,
        address beneficiary,
        uint256 cashOutCount,
        uint256 cashOutTaxRate,
        uint256 reclaimAmount,
        bytes metadata,
        address caller
    );

    function cashOutTokensOf(
        address holder,
        uint256 projectId,
        address tokenToReclaim,
        uint256 cashOutCount,
        uint256 minTokensReclaimed,
        address payable beneficiary,
        bytes calldata metadata
    )
        external
        returns (uint256 reclaimAmount);
}
