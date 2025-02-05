// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestUseAllowanceOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;

    function setUp() public {
        super.multiTerminalSetup();
    }

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

    function test_WhenBeneficiaryIsFeeless() external {
        address mockToken = makeAddr("token");
        address beneficiary = makeAddr("bene");

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

        // first feeless check which will return false.
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(false)
        );

        // second which is true for beneficiary.
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (beneficiary)), abi.encode(true)
        );

        mockExpect(mockToken, abi.encodeCall(IERC20.transfer, (beneficiary, 100)), abi.encode(true));

        vm.expectEmit();
        emit IJBPayoutTerminal.UseAllowance({
            rulesetId: returnedRuleset.id,
            rulesetCycleNumber: returnedRuleset.cycleNumber,
            projectId: _projectId,
            beneficiary: beneficiary,
            feeBeneficiary: address(this),
            amount: 100,
            amountPaidOut: 100,
            netAmountPaidOut: 100,
            memo: "",
            caller: address(this)
        });

        _terminal.useAllowanceOf({
            projectId: _projectId,
            token: mockToken,
            amount: 100,
            currency: 0,
            minTokensPaidOut: 100,
            beneficiary: payable(beneficiary),
            feeBeneficiary: payable(address(this)),
            memo: ""
        });
    }

    function test_WhenNotFeeless() external {
        address mockToken = makeAddr("token");
        address beneficiary = makeAddr("bene");

        // Mock controller for mint call on fee payments
        address controller = makeAddr("controller");

        // Weight for a fee calculation that would take place in terminal store
        uint112 weight = 1000 * 10 ** 18;

        uint32 currencyId = uint32(uint160(mockToken));

        // Start the cascade of issuing project tokens to the fee beneficiary. (recieving platform tokens for paying a
        // fee, or being designated as such).
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(controller))
        );

        // mock owner call
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(this)));

        // needed for terminal store mock call
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: weight,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to tokens decimals()
        mockExpect(mockToken, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(18));

        // mock call to rulesets currentOf returning 0 to bypass ruleset checking
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(returnedRuleset));

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({token: mockToken, decimals: 18, currency: currencyId});

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        _terminal.accountingContextForTokenOf(_projectId, mockToken);

        // recordUsedAllowance
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordUsedAllowanceOf, (_projectId, _tokens[0], 100, 0)),
            abi.encode(returnedRuleset, 100)
        );

        // first feeless check which will return false.
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(false)
        );

        // second which is also false.
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (beneficiary)), abi.encode(false)
        );

        mockExpect(mockToken, abi.encodeCall(IERC20.transfer, (beneficiary, 98)), abi.encode(true));

        // call to find the primary terminal for fee processing
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (1, mockToken)),
            abi.encode(address(_terminal))
        );

        JBTokenAmount memory tokenContext =
            JBTokenAmount({token: mockToken, decimals: 18, currency: currencyId, value: 2});

        // mock call to jbterminalstore
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom,
                // feeBeneficiary will receive platform tokens for paying a fee, project id is encoded for memo
                (address(_terminal), tokenContext, _projectId, address(this), bytes(abi.encodePacked(_projectId)))
            ),
            abi.encode(returnedRuleset, 1, new JBPayHookSpecification[](0))
        );

        // Return the mint of call as minting one project token for paying a fee.
        mockExpect(
            address(controller),
            abi.encodeCall(IJBController.mintTokensOf, (_projectId, 1, address(this), "", true)),
            abi.encode(2)
        );

        vm.expectEmit();
        emit IJBPayoutTerminal.UseAllowance({
            rulesetId: returnedRuleset.id,
            rulesetCycleNumber: returnedRuleset.cycleNumber,
            projectId: _projectId,
            beneficiary: beneficiary,
            feeBeneficiary: address(this),
            amount: 100,
            amountPaidOut: 100,
            netAmountPaidOut: 98,
            memo: "",
            caller: address(this)
        });

        _terminal.useAllowanceOf({
            projectId: _projectId,
            token: mockToken,
            amount: 100,
            currency: 0,
            minTokensPaidOut: 97,
            beneficiary: payable(beneficiary),
            feeBeneficiary: payable(address(this)),
            memo: ""
        });
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
