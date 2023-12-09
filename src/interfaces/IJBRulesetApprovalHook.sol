// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";

interface IJBRulesetApprovalHook is IERC165 {
    function DURATION() external view returns (uint40);

    function approvalStatusOf(
        uint32 projectId,
        uint40 rulesetId,
        uint40 start
    )
        external
        view
        returns (JBApprovalStatus);
}
