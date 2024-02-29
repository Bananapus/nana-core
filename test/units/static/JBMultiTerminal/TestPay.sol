// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestPay_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenTokensReturnedLTMinReturnedTokens() external {
        // it will revert UNDER_MIN_RETURNED_TOKENS
    }

    function test_WhenTerminalStoreReturnsTokenCountGTZeroAndHappypath() external {
        // it will mint tokens and emit Pay
    }

    modifier whenAPayHookIsConfiguredAndHappypath() {
        _;
    }

    function test_GivenThePaidTokenIsAnERC20() external whenAPayHookIsConfiguredAndHappypath {
        // it will increase allowance to the hook and emit HookAfterRecordPay and Pay
    }

    function test_GivenThePaidTokenIsNative() external whenAPayHookIsConfiguredAndHappypath {
        // it will send ETH to the hook and emit HookAfterRecordPay and Pay
    }

    function test_WhenTheProjectDNHAccountingContextForTheToken() external {
        // it will revert TOKEN_NOT_ACCEPTED
    }

    function test_WhenTheTerminalsTokenEqNativeToken() external {
        // it will use msg.value
    }

    function test_WhenTheTerminalsTokenEqNativeTokenAndMsgvalueEqZero() external {
        // it will revert NO_MSG_VALUE_ALLOWED
    }

    function test_WhenTheTerminalIsCallingItself() external {
        // it will not transfer
    }

    modifier whenPayMetadataContainsPermitData() {
        _;
    }

    function test_GivenThePermitAllowanceLtAmount() external whenPayMetadataContainsPermitData {
        // it will revert PERMIT_ALLOWANCE_NOT_ENOUGH
    }

    function test_GivenPermitAllowanceIsGood() external whenPayMetadataContainsPermitData {
        // it will set permit allowance to spend tokens for user via permit2
    }
}
