// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestGetRulesetOf_Local is JBRulesetsSetup {
    function setUp() public {
        super.rulesetsSetup();
    }

    function test_WhenRulesetIdDneqZero() external {
        // it will return a JBRuleset derived from _packedIntrinsicPropertiesOf
    }

    function test_WhenRulesetIdEqZero() external {
        // it will return an empty ruleset
    }
}
