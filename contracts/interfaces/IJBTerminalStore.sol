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

    function balanceOf(address terminal, uint256 projectId, address token)
        external
        view
        returns (uint256);

    function usedPayoutLimitOf(
        address terminal,
        uint256 projectId,
        address token,
        uint256 rulesetCycleNumber,
        uint256 currency
    ) external view returns (uint256);

    function usedSurplusAllowanceOf(
        address terminal,
        uint256 projectId,
        address token,
        uint256 rulesetId,
        uint256 currency
    ) external view returns (uint256);

    function currentSurplusOf(
        address terminal,
        uint256 projectId,
        JBAccountingContext[] calldata accountingContexts,
        uint256 decimals,
        uint256 currency
    ) external view returns (uint256);

    function currentTotalSurplusOf(uint256 projectId, uint256 decimals, uint256 currency)
        external
        view
        returns (uint256);

    function currentReclaimableSurplusOf(
        address terminal,
        uint256 projectId,
        JBAccountingContext[] calldata accountingContexts,
        uint256 _decimals,
        uint256 _currency,
        uint256 tokenCount,
        bool useTotalSurplus
    ) external view returns (uint256);

    function currentReclaimableSurplusOf(
        uint256 projectId,
        uint256 tokenCount,
        uint256 totalSupply,
        uint256 surplus
    ) external view returns (uint256);

    function recordPaymentFrom(
        address payer,
        JBTokenAmount memory amount,
        uint256 projectId,
        address beneficiary,
        bytes calldata metadata
    )
        external
        returns (
            JBRuleset memory ruleset,
            uint256 tokenCount,
            JBPayHookPayload[] memory hookPayloads
        );

    function recordRedemptionFor(
        address holder,
        uint256 projectId,
        JBAccountingContext calldata accountingContext,
        JBAccountingContext[] calldata balanceAccountingContexts,
        uint256 tokenCount,
        bytes calldata metadata
    )
        external
        returns (
            JBRuleset memory ruleset,
            uint256 reclaimAmount,
            JBRedeemHookPayload[] memory hookPayloads
        );

    function recordPayoutFor(
        uint256 projectId,
        JBAccountingContext calldata accountingContext,
        uint256 amount,
        uint256 currency
    ) external returns (JBRuleset memory ruleset, uint256 amountPaidOut);

    function recordUsedAllowanceOf(
        uint256 projectId,
        JBAccountingContext calldata accountingContext,
        uint256 amount,
        uint256 currency
    ) external returns (JBRuleset memory ruleset, uint256 withdrawnAmount);

    function recordAddedBalanceFor(uint256 projectId, address token, uint256 amount) external;

    function recordTerminalMigration(uint256 projectId, address token)
        external
        returns (uint256 balance);
}
