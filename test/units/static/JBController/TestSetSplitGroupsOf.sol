// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSetSplitGroupsOf_Local is JBControllerSetup {
    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsPermissioned() external {
        // it will set splits
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED
    }
}