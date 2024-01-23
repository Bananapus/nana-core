// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestPayoutLimitsOf_Local is JBFundAccessSetup {
    function setUp() public {
        super.fundAccessSetup();
    }

    modifier whenAProjectHasPayoutLimits() {
        _;
    }

    function test_GivenTheyAreConfiguredForASpecificToken() external whenAProjectHasPayoutLimits {
        // it will return them
    }

    function test_GivenTheyAreConfiguredForASpecificTerminal() external whenAProjectHasPayoutLimits {
        // it will return them
    }

    function test_GivenTheyAreConfiguredForASpecificRulesetId() external whenAProjectHasPayoutLimits {
        // it will return them
    }
}
