// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBAccountingContext} from "../../structs/JBAccountingContext.sol";
import {JBAccountingContextConfig} from "../../structs/JBAccountingContextConfig.sol";
import {JBDidPayData} from "../../structs/JBDidPayData.sol";

import {IJBPayHook} from "../../interfaces/IJBPayHook.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @notice A terminal that accepts payments and can be migrated.
interface IJBTerminal is IERC165 {
    event MigrateTerminal(
        uint32 indexed projectId, address indexed token, IJBTerminal indexed to, uint256 amount, address caller
    );

    event AddToBalance(
        uint32 indexed projectId, uint256 amount, uint256 unlockedFees, string memo, bytes metadata, address caller
    );

    event SetAccountingContext(
        uint32 indexed projectId, address indexed token, JBAccountingContext context, address caller
    );

    event Pay(
        uint256 indexed rulesetId,
        uint256 indexed rulesetCycleNumber,
        uint32 indexed projectId,
        address payer,
        address beneficiary,
        uint256 amount,
        uint256 beneficiaryTokenCount,
        string memo,
        bytes metadata,
        address caller
    );

    event HookDidPay(IJBPayHook indexed hook, JBDidPayData data, uint256 payloadAmount, address caller);

    function accountingContextForTokenOf(
        uint32 projectId,
        address token
    )
        external
        view
        returns (JBAccountingContext memory);

    function accountingContextsOf(uint32 projectId) external view returns (JBAccountingContext[] memory);

    function currentSurplusOf(uint32 projectId, uint256 decimals, uint256 currency) external view returns (uint256);

    function migrateBalanceOf(uint32 projectId, address token, IJBTerminal to) external returns (uint256 balance);

    function addAccountingContextsFor(
        uint32 projectId,
        JBAccountingContextConfig[] calldata accountingContexts
    )
        external;

    function pay(
        uint32 projectId,
        address token,
        uint256 amount,
        address beneficiary,
        uint256 minReturnedTokens,
        string calldata memo,
        bytes calldata metadata
    )
        external
        payable
        returns (uint256 beneficiaryTokenCount);

    function addToBalanceOf(
        uint32 projectId,
        address token,
        uint256 amount,
        bool shouldUnlockHeldFees,
        string calldata memo,
        bytes calldata metadata
    )
        external
        payable;
}
