// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetTerminalsOf_Local is JBTest, JBDirectorySetup {
    function setUp() public {
        super.directorySetup();
    }

    modifier whenCallerHasPermission() {
        _;
    }

    modifier givenThatSetTerminalsAllowed() {
        _;
    }

    function test_GivenThatNotSetTerminalsAllowed() external whenCallerHasPermission {
        // it should revert with revert SET_TERMINALS_NOT_ALLOWED()
    }

    function test_WhenCallerHasNoPermission() external {
        // it should revert with UNAUTHORIZED()
    }

    function test_GivenThatDuplicateTerminalsWereAdded()
        external
        whenCallerHasPermission
        givenThatSetTerminalsAllowed
    {
        // it should revert with DUPLICATE_TERMINALS()
    }

    function test_GivenThatDuplicateTerminalsWereNotAdded()
        external
        whenCallerHasPermission
        givenThatSetTerminalsAllowed
    {
        // it should set terminals and emit SetTerminals
    }
}
