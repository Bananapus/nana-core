// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";
import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBRulesetData} from "./../structs/JBRulesetData.sol";

interface IJBRulesets {
    event RulesetQueued(
        uint256 indexed rulesetId,
        uint256 indexed projectId,
        JBRulesetData data,
        uint256 metadata,
        uint256 mustStartAtOrAfter,
        address caller
    );

    event RulesetInitialized(
        uint256 indexed rulesetId, uint256 indexed projectId, uint256 indexed basedOnId
    );

    function latestRulesetIdOf(uint256 projectId) external view returns (uint256);

    function getRulesetStruct(uint256 projectId, uint256 rulesetId)
        external
        view
        returns (JBRuleset memory);

    function latestQueuedRulesetOf(uint256 projectId)
        external
        view
        returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus);

    function upcomingRulesetOf(uint256 projectId)
        external
        view
        returns (JBRuleset memory ruleset);

    function currentOf(uint256 projectId) external view returns (JBRuleset memory ruleset);

    function currentApprovalStatusForLatestRulesetOf(uint256 projectId)
        external
        view
        returns (JBApprovalStatus);

    function queueFor(
        uint256 projectId,
        JBRulesetData calldata data,
        uint256 metadata,
        uint256 mustStartAtOrAfter
    ) external returns (JBRuleset memory ruleset);

    function updateRulesetWeightCache(uint256 projectId) external;
}