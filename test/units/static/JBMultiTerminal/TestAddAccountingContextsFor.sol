// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAddAccountingContextsFor_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED
    }

    modifier whenCallerIsPermissioned() {
        _;
    }

    function test_GivenTheContextIsAlreadySet() external whenCallerIsPermissioned {
        // it will revert ACCOUNTING_CONTEXT_ALREADY_SET
    }

    function test_GivenHappypath() external whenCallerIsPermissioned {
        // it will set the context and emit SetAccountingContext
    }

    function test_WhenCallerIsController() external {
        // it will alsoGrantAccess
    }
}
