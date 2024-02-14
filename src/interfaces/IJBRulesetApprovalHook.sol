// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBApprovalStatus} from "./../enums/JBApprovalStatus.sol";

interface IJBRulesetApprovalHook is IERC165 {
    function DURATION() external view returns (uint256);

    function approvalStatusOf(
        uint256 projectId,
        uint256 rulesetId,
        uint256 start
    )
        external
        view
        returns (JBApprovalStatus);
}
