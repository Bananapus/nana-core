// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestMigrateBalanceOf_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenCallerDoesNotHavePermission() external {
        // it will revert UNAUTHORIZED
    }

    function test_WhenTheTerminalToDoesNotAcceptTheToken() external {
        // it will revert TERMINAL_TOKENS_INCOMPATIBLE
    }

    modifier whenBalanceGTZeroAndCallerIsPermissioned() {
        _;
    }

    function test_GivenThereAreHeldFees() external whenBalanceGTZeroAndCallerIsPermissioned {
        // it will process held fees
    }

    function test_GivenTokenIsERC20() external whenBalanceGTZeroAndCallerIsPermissioned {
        // it will safeIncreaseAllowance and addToBalanceOf
    }

    function test_GivenTokenIsNative() external whenBalanceGTZeroAndCallerIsPermissioned {
        // it will addToBalanceOf with value in msgvalue
    }
}
