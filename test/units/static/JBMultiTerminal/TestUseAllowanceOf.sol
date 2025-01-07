// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestUseAllowanceOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;

    function setUp() public {
        super.multiTerminalSetup();
    }

    /* function test_WhenCallerDoesNotHavePermission() external {
        // it will revert UNAUTHORIZED
    } */

    function test_WhenAmountPaidOutLTMinTokensPaidOut() external {
        // it will revert UNDER_MIN_TOKENS_PAID_OUT

        // mock owner call
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(this)));

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});

        // recordUsedAllowance
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordUsedAllowanceOf, (_projectId, mockTokenContext, 0, 0)),
            abi.encode(returnedRuleset, 0)
        );

        // feeless check
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(true)
        );

        vm.expectRevert(abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_UnderMinTokensPaidOut.selector, 0, 1));
        _terminal.useAllowanceOf(_projectId, address(0), 0, 0, 1, payable(address(this)), payable(address(this)), "");
    }

    function test_WhenOwnerEQFeeless() external {
        // it will not incur fees

        address mockToken = makeAddr("token");

        // mock owner call
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(this)));

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});

        // recordUsedAllowance
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordUsedAllowanceOf, (_projectId, mockTokenContext, 100, 0)),
            abi.encode(returnedRuleset, 100)
        );

        // feeless check
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(true)
        );

        mockExpect(mockToken, abi.encodeCall(IERC20.transfer, (address(this), 100)), abi.encode(true));

        vm.expectEmit();
        emit IJBPayoutTerminal.UseAllowance({
            rulesetId: returnedRuleset.id,
            rulesetCycleNumber: returnedRuleset.cycleNumber,
            projectId: _projectId,
            beneficiary: address(this),
            feeBeneficiary: address(this),
            amount: 100,
            amountPaidOut: 100,
            netAmountPaidOut: 100,
            memo: "",
            caller: address(this)
        });
        _terminal.useAllowanceOf(_projectId, mockToken, 100, 0, 0, payable(address(this)), payable(address(this)), "");
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
