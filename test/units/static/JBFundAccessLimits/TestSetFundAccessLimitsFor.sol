// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestSetFundAccessLimitsFor_Local is JBFundAccessSetup {
    function setUp() public {
        super.fundAccessSetup();
    }

    function test_WhenCallerIsNotController() external {
        // it will revert
    }

    modifier whenCallerIsControllerOfProject() {
        _;
    }

    function test_GivenPayoutLimitAmountIsGtUint224() external whenCallerIsControllerOfProject {
        // it will revert INVALID_PAYOUT_LIMIT
    }

    function test_GivenPayoutLimitCurrencyIsGtUint32() external whenCallerIsControllerOfProject {
        // it will revert INVALID_PAYOUT_LIMIT_CURRENCY
    }

    function test_GivenPayoutLimitCurrencyIsNotGivenInAscendingOrder() external whenCallerIsControllerOfProject {
        // it will revert INVALID_PAYOUT_LIMIT_CURRENCY_ORDERING
    }

    function test_GivenSurplusAllowanceAmountGtUint224() external whenCallerIsControllerOfProject {
        // it will revert INVALID_SURPLUS_ALLOWANCE
    }

    function test_GivenSurplusAllowanceCurrencyGtUint32() external whenCallerIsControllerOfProject {
        // it will revert INVALID_PAYOUT_LIMIT_CURRENCY
    }

    function test_GivenSurplusAllowanceCurrenciesAreNotAscendingOrder() external whenCallerIsControllerOfProject {
        // it will revert INVALID_SURPLUS_ALLOWANCE_CURRENCY_ORDERING
    }

    function test_GivenValidConfig() external whenCallerIsControllerOfProject {
        // it will set packed properties and emit SetFundAccessLimits
    }
}
