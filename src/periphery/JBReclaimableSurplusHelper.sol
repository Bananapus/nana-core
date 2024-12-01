// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBSurplus} from "../libraries/JBSurplus.sol";
import {JBCashOuts} from "../libraries/JBCashOuts.sol";
import {JBRulesetMetadataResolver} from "../libraries/JBRulesetMetadataResolver.sol";

import {IJBDirectory} from "../interfaces/IJBDirectory.sol";
import {IJBController} from "../interfaces/IJBController.sol";
import {IJBRulesets} from "../interfaces/IJBRulesets.sol";
import {JBRuleset} from "../structs/JBRuleset.sol";

/// @notice a UI helper contract for getting the current total reclaimable surplus of a project.
contract JBReclaimableSurplusHelper {
    // A library that parses the packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    IJBDirectory public immutable DIRECTORY;
    IJBRulesets public immutable RULESETS;

    constructor(IJBDirectory directory, IJBRulesets rulesets) {
        DIRECTORY = directory;
        RULESETS = rulesets;
    }

    function currentTotalSurplusOf(
        uint256 projectId,
        uint256 decimals,
        uint256 currency
    )
        external
        view
        returns (uint256 surplus)
    {
        return JBSurplus.currentSurplusOf(projectId, DIRECTORY.terminalsOf(projectId), decimals, currency);
    }

    function currentTotalReclaimableSurplusOf(
        uint256 projectId,
        uint256 cashOutCount,
        uint256 decimals,
        uint256 currency
    )
        external
        view
        returns (uint256 surplus)
    {
        // Get a reference to the project's current ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        uint256 currentSurplus =
            JBSurplus.currentSurplusOf(projectId, DIRECTORY.terminalsOf(projectId), decimals, currency);

        // If there's no surplus, nothing can be reclaimed.
        if (currentSurplus == 0) return 0;

        // Get the project token's total supply.
        uint256 totalSupply =
            IJBController(address(DIRECTORY.controllerOf(projectId))).totalTokenSupplyWithReservedTokensOf(projectId);

        // Can't cash out more tokens than are in the total supply.
        if (cashOutCount > totalSupply) return 0;

        // Return the amount of surplus terminal tokens that would be reclaimed.
        return JBCashOuts.cashOutFrom({
            surplus: currentSurplus,
            cashOutCount: cashOutCount,
            totalSupply: totalSupply,
            cashOutTaxRate: ruleset.cashOutTaxRate()
        });
    }
}
