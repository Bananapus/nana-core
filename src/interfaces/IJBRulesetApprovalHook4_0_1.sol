// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";

/// @notice `IJBRulesetApprovalHook`s are used to determine whether the next ruleset in the ruleset queue is approved or
/// rejected.
/// @dev Project rulesets are stored in a queue. Rulesets take effect after the previous ruleset in the queue ends, and
/// only if they are approved by the previous ruleset's approval hook.
interface IJBRulesetApprovalHook is IERC165 {
    function DURATION() external view returns (uint256);

    function approvalStatusOf(uint256 projectId, JBRuleset memory ruleset) external view returns (JBApprovalStatus);
}
