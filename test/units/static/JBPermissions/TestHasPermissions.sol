// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract TestHasPermissions_Local {
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
