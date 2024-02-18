// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordUsedAllowanceOf_Local is JBTerminalStoreSetup {
    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenAmountIsWithinRangeToUseSurplusAllowance() {
        _;
    }

    function test_GivenCallingCurrencyEqAccountingCurrency() external whenAmountIsWithinRangeToUseSurplusAllowance {
        // it will not convert prices
    }

    function test_GivenCallingCurrencyDneqAccountingCurrency() external whenAmountIsWithinRangeToUseSurplusAllowance {
        // it will convert prices
    }

    function test_GivenThereIsInadequateBalanceAfterPriceConversion()
        external
        whenAmountIsWithinRangeToUseSurplusAllowance
    {
        // it will revert INADEQUATE_TERMINAL_STORE_BALANCE
    }

    function test_WhenAmountIsNotWithinRangeToUseSurplusAllowance() external {
        // it will revert INADEQUATE_CONTROLLER_ALLOWANCE
    }
}
