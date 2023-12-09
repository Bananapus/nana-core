// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBPayHookPayload} from "./../structs/JBPayHookPayload.sol";
import {JBRedeemHookPayload} from "./../structs/JBRedeemHookPayload.sol";
import {JBAccountingContext} from "./../structs/JBAccountingContext.sol";
import {JBTokenAmount} from "./../structs/JBTokenAmount.sol";
import {IJBDirectory} from "./IJBDirectory.sol";
import {IJBRulesets} from "./IJBRulesets.sol";
import {IJBPrices} from "./IJBPrices.sol";

interface IJBTerminalStore {
    function RULESETS() external view returns (IJBRulesets);

    function DIRECTORY() external view returns (IJBDirectory);

    function PRICES() external view returns (IJBPrices);

    function balanceOf(address terminal, uint32 projectId, address token) external view returns (uint160);

    function usedPayoutLimitOf(
        address terminal,
        uint32 projectId,
        address token,
        uint40 rulesetCycleNumber,
        uint32 currency
    )
        external
        view
        returns (uint160);

    function usedSurplusAllowanceOf(
        address terminal,
        uint32 projectId,
        address token,
        uint40 rulesetId,
        uint32 currency
    )
        external
        view
        returns (uint160);

    function currentSurplusOf(
        address terminal,
        uint32 projectId,
        JBAccountingContext[] calldata accountingContexts,
        uint8 decimals,
        uint32 currency
    )
        external
        view
        returns (uint160);

    function currentTotalSurplusOf(uint32 projectId, uint8 decimals, uint32 currency) external view returns (uint160);

    function currentReclaimableSurplusOf(
        address terminal,
        uint32 projectId,
        JBAccountingContext[] calldata accountingContexts,
        uint8 decimals,
        uint32 currency,
        uint160 tokenCount,
        bool useTotalSurplus
    )
        external
        view
        returns (uint160);

    function currentReclaimableSurplusOf(
        uint32 projectId,
        uint160 tokenCount,
        uint160 totalSupply,
        uint160 surplus
    )
        external
        view
        returns (uint160);

    function recordPaymentFrom(
        address payer,
        JBTokenAmount memory amount,
        uint32 projectId,
        address beneficiary,
        bytes calldata metadata
    )
        external
        returns (JBRuleset memory ruleset, uint160 tokenCount, JBPayHookPayload[] memory hookPayloads);

    function recordRedemptionFor(
        address holder,
        uint32 projectId,
        JBAccountingContext calldata accountingContext,
        JBAccountingContext[] calldata balanceAccountingContexts,
        uint160 tokenCount,
        bytes calldata metadata
    )
        external
        returns (JBRuleset memory ruleset, uint160 reclaimAmount, JBRedeemHookPayload[] memory hookPayloads);

    function recordPayoutFor(
        uint32 projectId,
        JBAccountingContext calldata accountingContext,
        uint160 amount,
        uint32 currency
    )
        external
        returns (JBRuleset memory ruleset, uint160 amountPaidOut);

    function recordUsedAllowanceOf(
        uint32 projectId,
        JBAccountingContext calldata accountingContext,
        uint160 amount,
        uint32 currency
    )
        external
        returns (JBRuleset memory ruleset, uint160 withdrawnAmount);

    function recordAddedBalanceFor(uint32 projectId, address token, uint160 amount) external;

    function recordTerminalMigration(uint32 projectId, address token) external returns (uint160 balance);
}
