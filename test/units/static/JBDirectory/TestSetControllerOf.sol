// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetControllerOf_Local is JBTest, JBDirectorySetup {
    function setUp() public {
        super.directorySetup();
    }

    modifier givenThatTheProjectExists() {
        _;
    }

    modifier whenCallerIsAllowedToSetFirstControllerOrHasPermission() {
        _;
    }

    function test_RevertWhen_CallerDoesNotHaveAnyPermission() external {
        // it should revert
    }

    function test_RevertGiven_ThatAProjectDoesntExist()
        external
        whenCallerIsAllowedToSetFirstControllerOrHasPermission
    {
        // it should revert
    }

    function test_RevertGiven_ThatTheCurrentControllerIsNotSetControllerAllowed()
        external
        whenCallerIsAllowedToSetFirstControllerOrHasPermission
        givenThatTheProjectExists
    {
        // it should revert
    }

    function test_GivenThatTheCurrentControllerIsSetControllerAllowed()
        external
        whenCallerIsAllowedToSetFirstControllerOrHasPermission
        givenThatTheProjectExists
    {
        // it should set controllerOf and emit SetController
    }
}
