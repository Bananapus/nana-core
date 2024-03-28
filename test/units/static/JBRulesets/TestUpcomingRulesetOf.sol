// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestUpcomingRulesetOf_Local is JBRulesetsSetup {

    function setUp() public {
        super.rulesetsSetup();
    }

    function test_WhenLatestRulesetIdEQZero() external {
        // it will return an empty ruleset
    }

    modifier whenUpcomingRulesetIdDNEQZero() {
        _;
    }

    function test_GivenStatusEQApprovedOrApprovalExpectedOrEmpty() external whenUpcomingRulesetIdDNEQZero {
        // it will return that ruleset
    }

    function test_GivenStatusDNEQApprovedOrApprovalExpectedOrEmpty() external whenUpcomingRulesetIdDNEQZero {
        // it will return the ruleset upcoming was based on
    }

    modifier whenUpcomingRulesetIdEQZero() {
        _;
    }

    function test_GivenTheLatestRulesetStartsInTheFuture() external whenUpcomingRulesetIdEQZero {
        // it will return the ruleset that latestRuleset is based on
    }

    function test_WhenLatestRulesetHasDurationEqZero() external {
        // it will return an empty ruleset
    }

    modifier whenRulesetDurationDneqZero() {
        _;
    }

    function test_GivenApprovalStatusIsApprovedOrEmpty() external whenRulesetDurationDneqZero {
        // it will return a simulatedCycledRulesetBasedOn
    }

    function test_GivenTheRulesetsApprovalFailedAndItsBasedOnDurationDNEQZero() external whenRulesetDurationDneqZero {
        // it will return the simulatedCycledRulesetBasedOn it was based on
    }

    function test_GivenTheRulesetsApprovalFailedAndItsBasedOnDurationEQZero() external whenRulesetDurationDneqZero {
        // it will return an empty ruleset
    }
}
