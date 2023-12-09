// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";
import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBRulesetData} from "./../structs/JBRulesetData.sol";
import {IJBControlled} from "./IJBControlled.sol";

interface IJBRulesets is IJBControlled {
    event RulesetQueued(
        uint40 indexed rulesetId,
        uint32 indexed projectId,
        JBRulesetData data,
        uint256 metadata,
        uint40 mustStartAtOrAfter,
        address caller
    );

    event RulesetInitialized(uint40 indexed rulesetId, uint32 indexed projectId, uint40 indexed basedOnId);

    function latestRulesetIdOf(uint32 projectId) external view returns (uint40);

    function getRulesetOf(uint32 projectId, uint40 rulesetId) external view returns (JBRuleset memory);

    function latestQueuedRulesetOf(uint32 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus);

    function upcomingRulesetOf(uint32 projectId) external view returns (JBRuleset memory ruleset);

    function currentOf(uint32 projectId) external view returns (JBRuleset memory ruleset);

    function currentApprovalStatusForLatestRulesetOf(uint32 projectId) external view returns (JBApprovalStatus);

    function queueFor(
        uint32 projectId,
        JBRulesetData calldata data,
        uint256 metadata,
        uint40 mustStartAtOrAfter
    )
        external
        returns (JBRuleset memory ruleset);

    function updateRulesetWeightCache(uint32 projectId) external;
}
