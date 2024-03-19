// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestProcessHeldFeesOf_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenHeldFeeUnlockTimestampGTBlocktimestamp() external {
        // it will add the fee back to _heldFeesOf
    }

    modifier whenHeldFeeIsUnlocked() {
        _;
    }

    function test_GivenExecuteProcessFeeSucceeds() external whenHeldFeeIsUnlocked {
        // it will process the fee and emit ProcessFee
    }

    function test_GivenExecuteProcessFeeFails() external whenHeldFeeIsUnlocked {
        // it will readd balance and emit FeeReverted
    }
}
