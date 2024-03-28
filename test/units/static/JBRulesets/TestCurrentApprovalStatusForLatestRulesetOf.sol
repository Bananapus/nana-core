// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestCurrentApprovalStatusForLatestRulesetOf_Local is JBRulesetsSetup {

    function setUp() public {
        super.rulesetsSetup();
    }

    modifier whenARulesetIsConfigured() {
        _;
    }

    function test_GivenTheBasedOnRulesetEqZero() external whenARulesetIsConfigured {
        // it will return status Empty
    }

    function test_GivenThereIsNoApprovalHook() external whenARulesetIsConfigured {
        // it will return status Empty
    }

    function test_GivenBasedOnDNEQZeroAndThereIsAnApprovalHook() external whenARulesetIsConfigured {
        // it will return the approval status
    }
}
