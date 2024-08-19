// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestRulesetsOf_Local is JBRulesetsSetup {
    // Necessary params
    uint256 _projectId = 1;

    function setUp() public {
        super.rulesetsSetup();
    }

    function test_WhenStartingIdEqZero() external {
        // it will return latest ruleset
    }

    function test_WhenStartingIdDneqZero() external {
        // it will return predecessors up to latest ruleset
    }

    function test_WhenSizeIsZero() external {
        // it will return an empty array

        JBRuleset[] memory _rulesets = _rulesets.allOf(_projectId, 0, 0);
        assertEq(_rulesets.length, 0);
    }

    function test_WhenThereAreNoRulesets() external {
        // it will return an empty array
    }

    function test_WhenSizeIsGtConfiguredRulesets() external {
        // it will return up to latest ruleset
    }
}
