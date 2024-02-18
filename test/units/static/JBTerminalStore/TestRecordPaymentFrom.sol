// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordPaymentFrom_Local is JBTerminalStoreSetup {
    function setUp() public {
        super.terminalStoreSetup();
    }

    function test_WhenCurrentRulesetCycleNumberIsZero() external {
        // it will revert INVALID_RULESET
    }

    function test_WhenCurrentRulesetPausePayEqTrue() external {
        // it will revert RULESET_PAYMENT_PAUSED
    }

    modifier whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress() {
        _;
    }

    function test_GivenTheHookReturnsANonZeroSpecifiedAmount()
        external
        whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress
    {
        // it will decrement the amount being added to the local balance
    }

    function test_GivenWeightReturnedByTheHookIsZero()
        external
        whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress
    {
        // it will return zero as the tokenCount
    }

    function test_WhenAHookIsNotConfigured() external {
        // it will derive weight from the ruleset
    }

    function test_WhenTheTerminalShouldBaseItsWeightOnACurrencyOtherThanTheRulesetBaseCurrency() external {
        // it will return an adjusted weightRatio
    }
}
