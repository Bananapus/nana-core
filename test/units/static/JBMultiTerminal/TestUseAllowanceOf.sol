// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestUseAllowanceOf_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenCallerDoesNotHavePermission() external {
        // it will revert UNAUTHORIZED
    }

    function test_WhenAmountPaidOutLTMinTokensPaidOut() external {
        // it will revert INADEQUATE_PAYOUT_AMOUNT
    }

    function test_WhenMsgSenderEQFeeless() external {
        // it will not incur fees
    }

    modifier whenMsgSenderDNEQFeeless() {
        _;
    }

    function test_GivenRulesetHoldFeesEQTrue() external whenMsgSenderDNEQFeeless {
        // it will hold fees and emit HoldFee
    }

    function test_GivenRulesetHoldFeesDNEQTrue() external whenMsgSenderDNEQFeeless {
        // it will not hold fees and emit ProcessFee
    }

    function test_WhenTokenEQNATIVE_TOKEN() external {
        // it will send ETH via sendValue
    }

    function test_WhenTokenEQERC20() external {
        // it will call safeTransfer
    }
}
