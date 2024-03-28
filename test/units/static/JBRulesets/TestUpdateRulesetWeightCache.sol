// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestUpdateRulesetWeightCache_Local is JBRulesetsSetup {
    function setUp() public {
        super.rulesetsSetup();
    }

    function test_WhenLatestRulesetOfProjectDurationOrDecayRateEQZero() external {
        // it will return without updating
    }

    function test_WhenLatestRulesetHasProperDurationAndDecayRate() external {
        // it will store a new derivedWeightFrom and decayMultiple in storage
    }
}
