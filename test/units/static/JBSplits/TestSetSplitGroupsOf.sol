// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBSplitsSetup} from "./JBSplitsSetup.sol";

contract TestSetSplitGroupsOf_Local is JBSplitsSetup {
    function setUp() public {
        super.splitsSetup();
    }

    function test_WhenCallerIsNotController() external {
        // it will revert with CONTROLLER_UNAUTHORIZED
    }

    modifier whenCallerIsController() {
        _;
    }

    function test_GivenPreviouslyLockedSplitsAreNotIncluded() external whenCallerIsController {
        // it will revert with PREVIOUS_LOCKED_SPLITS_NOT_INCLUDED
    }

    modifier givenPreviouslyLockedSplitsAreIncluded() {
        _;
    }

    function test_GivenAnyConfiguredSplitPercentIsZero()
        external
        whenCallerIsController
        givenPreviouslyLockedSplitsAreIncluded
    {
        // it will revert with INVALID_SPLIT_PERCENT
    }

    function test_GivenProjectIdGtUint56Max() external whenCallerIsController givenPreviouslyLockedSplitsAreIncluded {
        // it will revert with INVALID_PROJECT_ID
    }

    function test_GivenSplitsTotalToOverSPLITS_TOTAL_PERCENT()
        external
        whenCallerIsController
        givenPreviouslyLockedSplitsAreIncluded
    {
        // it will revert with INVALID_TOTAL_PERCENT
    }

    function test_GivenLockedUntilGtUint48Max()
        external
        whenCallerIsController
        givenPreviouslyLockedSplitsAreIncluded
    {
        // it will revert with INVALID_LOCKED_UNTIL
    }

    function test_GivenAllConditionsAreSatisfied()
        external
        whenCallerIsController
        givenPreviouslyLockedSplitsAreIncluded
    {
        // it will store splits and emit SetSplit for each configured
    }
}
