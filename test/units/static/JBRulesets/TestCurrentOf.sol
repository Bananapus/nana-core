// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestCurrentOf_Local is JBRulesetsSetup {

    function setUp() public {
        super.rulesetsSetup();
    }

    function test_WhenLatestrulesetOfProjectEQZero() external {
        // it will return an empty ruleset
    }

    modifier whenLatestRulesetIdDNEQZero() {
        _;
    }

    function test_GivenTheCurrentlyApprovableRulesetIdOfApprovalStatusEQApprovedOrEmpty()
        external
        whenLatestRulesetIdDNEQZero
    {
        // it will return the latest approved ruleset
    }

    function test_GivenTheCurrentlyApprovableRulesetIdOfApprovalStatusDNEQApprovedOrEmpty()
        external
        whenLatestRulesetIdDNEQZero
    {
        // it will return the ruleset the pending approval ruleset is basedOn
    }

    function test_GivenTheCurrentlyApprovableRulesetIdOfEQZeroAndApprovalStatusOfTheLatestRulesetDNEQApprovedOrEmpty()
        external
        whenLatestRulesetIdDNEQZero
    {
        // it will return the basedOn of the latest ruleset
    }

    function test_WhenBaseOfTheCurrentlyApprovableRulesetIdOfDurationEQZero() external {
        // it will return simulateCycledRulesetBasedOn with allowMidRuleset true
    }
}
