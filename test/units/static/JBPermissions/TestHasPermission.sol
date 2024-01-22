// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPermissionsSetup} from "./JBPermissionsSetup.sol";

contract TestHasPermissions_Local is JBPermissionsSetup {
    function test_WhenPermissionIdGt255() external {
        // it will revert with PERMISSION_ID_OUT_OF_BOUNDS
    }

    modifier whenPermissionIdLt255() {
        _;
    }

    function test_GivenOperatorHasPermissionForAccountOfProject() external whenPermissionIdLt255 {
        // it will return true
    }

    function test_GivenOperatorDoesntHavePermissionForAccountOfProject() external whenPermissionIdLt255 {
        // it will return false
    }
}
