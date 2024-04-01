// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBSplitsSetup} from "./JBSplitsSetup.sol";

contract TestSplitsOf_Local is JBSplitsSetup {
    function setUp() public {
        super.splitsSetup();
    }

    // This is covered under TestSetSplitGroupsOf
    /* function test_WhenThereAreDefinedSplits() external {
        // it should return the defined splits
    } */

    function test_WhenThereAreNoSplitsDefined() external {
        // it should return the default splits for FALLBACK_RULESET_ID

        JBSplit[] memory _current = _splits.splitsOf(1, block.timestamp, 0);

        assertEq(_current.length, 0);
    }
}
