// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";
import {JBRuleset} from "./../structs/JBRuleset.sol";
import {IJBRulesetApprovalHook} from "./IJBRulesetApprovalHook.sol";

interface IJBRulesets {
    event RulesetInitialized(
        uint256 indexed rulesetId, uint256 indexed projectId, uint256 indexed basedOnId, address caller
    );
    event RulesetQueued(
        uint256 indexed rulesetId,
        uint256 indexed projectId,
        uint256 duration,
        uint256 weight,
        uint256 decayPercent,
        IJBRulesetApprovalHook approvalHook,
        uint256 metadata,
        uint256 mustStartAtOrAfter,
        address caller
    );

    function latestRulesetIdOf(uint256 projectId) external view returns (uint256);

    function currentApprovalStatusForLatestRulesetOf(uint256 projectId) external view returns (JBApprovalStatus);
    function currentOf(uint256 projectId) external view returns (JBRuleset memory ruleset);
    function deriveCycleNumberFrom(
        uint256 baseRulesetCycleNumber,
        uint256 baseRulesetStart,
        uint256 baseRulesetDuration,
        uint256 start
    )
        external
        returns (uint256);
    function deriveStartFrom(
        uint256 baseRulesetStart,
        uint256 baseRulesetDuration,
        uint256 mustStartAtOrAfter
    )
        external
        view
        returns (uint256 start);
    function deriveWeightFrom(
        uint256 projectId,
        uint256 baseRulesetStart,
        uint256 baseRulesetDuration,
        uint256 baseRulesetWeight,
        uint256 baseRulesetDecayPercent,
        uint256 baseRulesetCacheId,
        uint256 start
    )
        external
        view
        returns (uint256 weight);
    function getRulesetOf(uint256 projectId, uint256 rulesetId) external view returns (JBRuleset memory);
    function latestQueuedOf(uint256 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus);
    function allOf(
        uint256 projectId,
        uint256 startingId,
        uint256 size
    )
        external
        view
        returns (JBRuleset[] memory rulesets);
    function upcomingOf(uint256 projectId) external view returns (JBRuleset memory ruleset);

    function queueFor(
        uint256 projectId,
        uint256 duration,
        uint256 weight,
        uint256 decayPercent,
        IJBRulesetApprovalHook approvalHook,
        uint256 metadata,
        uint256 mustStartAtOrAfter
    )
        external
        returns (JBRuleset memory ruleset);
    function updateRulesetWeightCache(uint256 projectId) external;
}
