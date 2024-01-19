// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetPrimaryTerminalOf_Local is JBTest, JBDirectorySetup {
    function setUp() public {
        super.directorySetup();
    }

    modifier givenThatTheTerminalHasNotBeenAdded() {
        _;
    }

    modifier givenThatTheTerminalHasBeenAdded() {
        _;
    }

    modifier whenCallerHasPermission() {
        _;
    }

    modifier givenThatThereIsAnAccountingContextForTokenOf() {
        _;
    }

    function test_WhenCallerHasNoPermission() external {
        // it should revert with UNAUTHORIZED()
    }

    function test_GivenThatThereIsNoAccountingContextForTokenOf() external whenCallerHasPermission {
        // it should revert with TOKEN_NOT_ACCEPTED
    }

    function test_GivenThatTheTerminalHasAlreadyBeenAdded()
        external
        whenCallerHasPermission
        givenThatThereIsAnAccountingContextForTokenOf
    {
        // it should not add the terminal
    }

    function test_GivenThatTheProjectIsNotAllowedToSetTerminals()
        external
        whenCallerHasPermission
        givenThatThereIsAnAccountingContextForTokenOf
        givenThatTheTerminalHasNotBeenAdded
    {
        // it should revert with SET_TERMINALS_NOT_ALLOWED
    }

    function test_GivenThatTheProjectIsAllowedToSetTerminals()
        external
        whenCallerHasPermission
        givenThatThereIsAnAccountingContextForTokenOf
        givenThatTheTerminalHasNotBeenAdded
    {
        // it should set the terminal and emit AddTerminal
        // it should set the terminal as primary and emit SetPrimaryTerminal
    }
}
