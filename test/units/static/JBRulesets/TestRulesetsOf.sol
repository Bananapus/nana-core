// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestRulesetsOf_Local is JBRulesetsSetup {

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
    }

    function test_WhenThereAreNoRulesets() external {
        // it will return an empty array
    }

    function test_WhenSizeIsGtConfiguredRulesets() external {
        // it will return up to latest ruleset
    }
}
