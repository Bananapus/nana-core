// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract TestSetPermissionsFor_Local {
    function test_WhenCallerDoesNotHaveROOTPermission() external {
        // it will revert UNAUTHORIZED
    }

    function test_WhenCallerHasROOTPermission() external {
        // it packs permissions into a bitfield, stores them, and emits OperatorPermissionsSet
    }
}
