// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordPayoutFor_Local is JBTerminalStoreSetup {
    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenThereIsAUsedPayoutLimitOfTheCurrentRuleset() {
        _;
    }

    function test_GivenTheCallingAmountGtWhatIsAvailableToPayout()
        external
        whenThereIsAUsedPayoutLimitOfTheCurrentRuleset
    {
        // it will revert PAYOUT_LIMIT_EXCEEDED
    }

    function test_GivenTheCallingCurrencyEqTheContextCurrency()
        external
        whenThereIsAUsedPayoutLimitOfTheCurrentRuleset
    {
        // it will not convert prices and return
    }

    function test_GivenTheCallingCurrencyDneqTheContextCurrency()
        external
        whenThereIsAUsedPayoutLimitOfTheCurrentRuleset
    {
        // it will convert prices and return
    }

    function test_GivenTheAmountPaidOutExceedsBalance() external whenThereIsAUsedPayoutLimitOfTheCurrentRuleset {
        // it will revert INADEQUATE_TERMINAL_STORE_BALANCE
    }
}
