// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPermissionsSetup} from "./JBPermissionsSetup.sol";

contract TestSetPermissionsFor_Local is JBPermissionsSetup {
    function setUp() public {
        super.permissionsSetup();
    }

    function test_WhenCallerDoesNotHaveROOTPermission() external {
        // it will revert UNAUTHORIZED
    }

    function test_WhenCallerHasROOTPermission() external {
        // it packs permissions into a bitfield, stores them, and emits OperatorPermissionsSet
    }
}
