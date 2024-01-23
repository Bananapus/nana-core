// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestSurplusAllowanceOf_Local is JBFundAccessSetup {
    function setUp() public {
        super.fundAccessSetup();
    }

    function test_WhenAProjectHasTheSpecificSurplusConfigured() external {
        // it will return uin256 surplusAllowance
    }

    function test_WhenItDoesntHaveTheSpecificSurplusConfigured() external {
        // it will return 0
    }
}
