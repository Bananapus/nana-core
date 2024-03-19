// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestPayoutsOf_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenAmountPaidOutLtMinTokensPaidOut() external {
        // it will revert INADEQUATE_PAYOUT_AMOUNT
    }

    modifier whenASplitHookIsConfigured() {
        _;
    }

    function test_GivenTheSplitHookIsFeeless() external whenASplitHookIsConfigured {
        // it will not process a fee
    }

    function test_GivenTheSplitHookDNEQFeeless() external whenASplitHookIsConfigured {
        // it will process a fee
    }

    function test_GivenTheSplitHookDNSupportSplitHookInterface() external whenASplitHookIsConfigured {
        // it will revert 400_1
    }

    function test_GivenThePayoutTokenIsErc20() external whenASplitHookIsConfigured {
        // it will safe increase allowance
    }

    function test_GivenThePayoutTokenIsNative() external whenASplitHookIsConfigured {
        // it will send eth in msgvalue
    }

    modifier whenASplitProjectIdIsConfigured() {
        _;
    }

    function test_GivenTheProjectsTerminalEQZeroAddress() external whenASplitProjectIdIsConfigured {
        // it will revert 404_2
    }

    function test_GivenPreferAddToBalanceEQTrueAndTerminalEQThisAddress() external whenASplitProjectIdIsConfigured {
        // it will call _addToBalanceOf internal
    }

    function test_GivenPreferAddToBalanceEQTrueAndTerminalEQAnotherAddress() external whenASplitProjectIdIsConfigured {
        // it will call that terminals addToBalanceOf
    }

    function test_GivenPreferAddToBalanceDNEQTrueAndTerminalEQThisAddress() external whenASplitProjectIdIsConfigured {
        // it will call internal _pay
    }

    function test_GivenPreferAddToBalanceDNEQTrueAndTerminalEQAnotherAddress()
        external
        whenASplitProjectIdIsConfigured
    {
        // it will call that terminals pay function
    }

    modifier whenABeneficiaryIsConfigured() {
        _;
    }

    function test_GivenBeneficiaryEQFeeless() external whenABeneficiaryIsConfigured {
        // it will payout to the beneficiary without taking fees
    }

    function test_GivenBeneficiaryDNEQFeeless() external whenABeneficiaryIsConfigured {
        // it will payout to the beneficiary incurring fee
    }

    function test_WhenThereIsNoBeneficiarySplitHookOrProjectToPay() external {
        // it will payout msgSender
    }

    function test_WhenThereAreLeftoverPayoutFunds() external {
        // it will payout the rest to the project owner
    }
}
