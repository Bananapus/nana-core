// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordTerminalMigration_Local is JBTerminalStoreSetup {
    function setUp() public {
        super.terminalStoreSetup();
    }

    function test_WhenRulesetAllowsMigration() external {
        // it will return the current balance and set balance to zero
    }

    function test_WhenRulesetDnAllowMigration() external {
        // it will revert TERMINAL_MIGRATION_NOT_ALLOWED
    }
}
