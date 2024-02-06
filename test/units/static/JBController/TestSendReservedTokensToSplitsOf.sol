// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSendReservedTokensToSplitsOf_Local is JBControllerSetup {

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenTheProjectHasNoReservedTokenSplits() external {
        // it will mint to the project owner
    }

    modifier whenTheProjectHasReservedTokenSplits() {
        _;
    }

    function test_GivenAHookIsConfigured() external whenTheProjectHasReservedTokenSplits {
        // it will mint to hook and call its processSplitWith function
    }

    function test_GivenABeneficiaryIsConfigured() external whenTheProjectHasReservedTokenSplits {
        // it will mint for the beneficiary
    }

    function test_GivenTheProjectIdOfSplitIsNonzeroAndABeneficiaryAndHookAreNotConfigured()
        external
        whenTheProjectHasReservedTokenSplits
    {
        // it will mint to the owner of the project
    }

    function test_GivenProjectIdIsZeroAndNothingIsConfigured() external whenTheProjectHasReservedTokenSplits {
        // it will mint to whoever called sendReservedTokens
    }
}
