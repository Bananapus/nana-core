// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestExecuteProcessFee_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenCallerIsNotItself() external {
        // it will revert
    }

    function test_WhenFeeTerminalEQZeroAddress() external {
        // it will revert 404_1
    }

    function test_WhenTokenIsErc20() external {
        // it will safeIncreaseAllowance
    }

    function test_WhenFeeTerminalEQThisAddress() external {
        // it will call internal _pay
    }

    modifier whenFeeTerminalDNEQThisAddress() {
        _;
    }

    function test_GivenTokenEQNATIVE_TOKEN() external whenFeeTerminalDNEQThisAddress {
        // it will call external pay with msgvalue
    }

    function test_GivenTokenDNEQNATIVE_TOKEN() external whenFeeTerminalDNEQThisAddress {
        // it will call external pay with zero msgvalue
    }
}
