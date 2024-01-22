// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPermissionsSetup} from "./JBPermissionsSetup.sol";

contract TestHasPermissions_Local is JBPermissionsSetup {
    function setUp() public {
        super.permissionsSetup();
    }

    function test_WhenAnyPermissionIdGt255() external {
        // it will revert with PERMISSION_ID_OUT_OF_BOUNDS
    }

    modifier whenAllPermissionIdsLt255() {
        _;
    }

    function test_GivenOperatorDoesNotHaveAllPermissionsSpecified() external whenAllPermissionIdsLt255 {
        // it will return false
    }

    function test_GivenOperatorHasAllPermissionsSpecified() external whenAllPermissionIdsLt255 {
        // it will return true
    }
}
