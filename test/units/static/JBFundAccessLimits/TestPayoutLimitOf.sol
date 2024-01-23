// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestPayoutLimitOf_Local is JBFundAccessSetup {
    function setUp() public {
        super.fundAccessSetup();
    }

    function test_WhenTheProjectHasTheSpecificPayoutLimit() external {
        // it will return the uint256 payoutLimit
    }

    function test_WhenTheProjectDoesntHaveTheSpecificPayoutLimit() external {
        // it will return 0
    }
}
