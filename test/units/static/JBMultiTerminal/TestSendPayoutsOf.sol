// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestPayoutsOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;

    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenAmountPaidOutLtMinTokensPaidOut() external {
        // it will revert UNDER_MIN_TOKENS_PAID_OUT

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});

        // record payout mock call
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordPayoutFor, (_projectId, mockTokenContext, 0, 0)),
            abi.encode(returnedRuleset, 0)
        );

        // projects owner of
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(this)));

        // needed for splits return call
        JBSplit[] memory returnedSplits = new JBSplit[](0);

        // mock splits of call
        mockExpect(
            address(splits),
            abi.encodeCall(IJBSplits.splitsOf, (_projectId, returnedRuleset.id, 0)),
            abi.encode(returnedSplits)
        );

        // mock directory call for fee processing
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (1, address(0))),
            abi.encode(address(_terminal))
        );

        vm.expectRevert(abi.encodeWithSignature("UNDER_MIN_TOKENS_PAID_OUT()"));
        _terminal.sendPayoutsOf(_projectId, address(0), 0, 0, 1);
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
