// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestLatestQueuedRulesetOf_Local is JBRulesetsSetup {
    function setUp() public {
        super.rulesetsSetup();
    }

    modifier whenTheLatestRulesetIdDneqZero() {
        _;
    }

    function test_GivenTheRulesetIsBasedOnRulesetZero() external whenTheLatestRulesetIdDneqZero {
        // it will return JBApprovalStatus.Empty
    }

    function test_GivenTheRulesetIsBasedOnNonzeroRulesetAndTheBasedOnApprovalhookDneqZeroAddress()
        external
        whenTheLatestRulesetIdDneqZero
    {
        // it will return the approvalHooks approvalStatusOf
    }

    function test_GivenTheRulesetIsBasedOnNonzeroRulesetAndTheBasedOnApprovalhookEqZeroAddress()
        external
        whenTheLatestRulesetIdDneqZero
    {
        // it will return JBApprovalStatus.Empty
    }

    function test_WhenTheLatestRulesetIdEqZero() external {
        // it will return empty ruleset and JBApprovalStatus.Empty
    }
}
