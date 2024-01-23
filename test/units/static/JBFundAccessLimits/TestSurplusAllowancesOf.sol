// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestSurplusAllowancesOf_Local is JBFundAccessSetup {
    function setUp() public {
        super.fundAccessSetup();
    }

    modifier whenAProjectHasSpecifiedSurplusAllowances() {
        _;
    }

    function test_GivenTheyAreSpecifiedForASpecificRuleset() external whenAProjectHasSpecifiedSurplusAllowances {
        // it will return them
    }

    function test_GivenTheyAreSpecifiedForASpecificTerminal() external whenAProjectHasSpecifiedSurplusAllowances {
        // it will return them
    }

    function test_GivenTheyAreSpecifiedForASpecificToken() external whenAProjectHasSpecifiedSurplusAllowances {
        // it will return them
    }
}
