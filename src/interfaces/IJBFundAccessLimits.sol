// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBCurrencyAmount} from "./../structs/JBCurrencyAmount.sol";
import {JBFundAccessLimitGroup} from "./../structs/JBFundAccessLimitGroup.sol";

interface IJBFundAccessLimits {
    event SetFundAccessLimits(
        uint256 indexed rulesetId, uint256 indexed projectId, JBFundAccessLimitGroup limits, address caller
    );


    function payoutLimitOf(
        uint256 projectId,
        uint256 rulesetId,
        address terminal,
        address token,
        uint256 currency
    )
        external
        view
        returns (uint256 payoutLimit);
    function payoutLimitsOf(
        uint256 projectId,
        uint256 rulesetId,
        address terminal,
        address token
    )
        external
        view
        returns (JBCurrencyAmount[] memory payoutLimits);
    function surplusAllowanceOf(
        uint256 projectId,
        uint256 rulesetId,
        address terminal,
        address token,
        uint256 currency
    )
        external
        view
        returns (uint256 surplusAllowance);
    function surplusAllowancesOf(
        uint256 projectId,
        uint256 rulesetId,
        address terminal,
        address token
    )
        external
        view
        returns (JBCurrencyAmount[] memory surplusAllowances);

    function setFundAccessLimitsFor(
        uint256 projectId,
        uint256 rulesetId,
        JBFundAccessLimitGroup[] memory fundAccessConstaints
    )
        external;
}
