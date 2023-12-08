// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBFundAccessLimitGroup} from "./../structs/JBFundAccessLimitGroup.sol";
import {JBCurrencyAmount} from "./../structs/JBCurrencyAmount.sol";
import {IJBPayoutTerminal} from "./terminal/IJBPayoutTerminal.sol";

interface IJBFundAccessLimits is IERC165 {
    event SetFundAccessLimits(
        uint256 indexed rulesetId, uint256 indexed projectId, JBFundAccessLimitGroup limits, address caller
    );

    function payoutLimitsOf(
        uint32 projectId,
        uint256 rulesetId,
        address terminal,
        address token
    )
        external
        view
        returns (JBCurrencyAmount[] memory payoutLimits);

    function payoutLimitOf(
        uint32 projectId,
        uint256 rulesetId,
        address terminal,
        address token,
        uint256 currency
    )
        external
        view
        returns (uint256 payoutLimit);

    function surplusAllowancesOf(
        uint32 projectId,
        uint256 rulesetId,
        address terminal,
        address token
    )
        external
        view
        returns (JBCurrencyAmount[] memory surplusAllowances);

    function surplusAllowanceOf(
        uint32 projectId,
        uint256 rulesetId,
        address terminal,
        address token,
        uint256 currency
    )
        external
        view
        returns (uint256 surplusAllowance);

    function setFundAccessLimitsFor(
        uint32 projectId,
        uint256 rulesetId,
        JBFundAccessLimitGroup[] memory fundAccessConstaints
    )
        external;
}
