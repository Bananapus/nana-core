// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Projects can be launched.
contract TestFees_Local is TestBaseWorkflow {
    IJBController private _controller;
    JBRulesetMetadata private _metadata;
    JBRulesetMetadata private _feeProjectMetadata;
    IJBMultiTerminal private _terminal;
    IJBMultiTerminal private _terminal2;
    IJBRulesets private _rulesets;

    uint224 _nativePayAmount;
    uint224 _nativeDistLimit;

    uint256 private _projectId;
    address private _projectOwner;
    address private _beneficiary;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _terminal = jbMultiTerminal();
        _terminal2 = jbMultiTerminal2();
        _controller = jbController();
        _rulesets = jbRulesets();
        _nativePayAmount = 2 ether;
        _nativeDistLimit = 1 ether;

        _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: true,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: true,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        _feeProjectMetadata = JBRulesetMetadata({
            reservedPercent: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: true,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: true,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroupProjectOne = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({amount: 2 ether, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({amount: 0, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            _fundAccessLimitGroupProjectOne[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroupProjectTwo = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] =
                JBCurrencyAmount({amount: _nativeDistLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] =
                JBCurrencyAmount({amount: _nativeDistLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            _fundAccessLimitGroupProjectTwo[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _feeProjectRuleset = new JBRulesetConfig[](1);
        _feeProjectRuleset[0].mustStartAtOrAfter = 0;
        _feeProjectRuleset[0].duration = 0;
        _feeProjectRuleset[0].weight = 0;
        _feeProjectRuleset[0].decayPercent = 0;
        _feeProjectRuleset[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _feeProjectRuleset[0].metadata = _feeProjectMetadata;
        _feeProjectRuleset[0].splitGroups = new JBSplitGroup[](0);
        _feeProjectRuleset[0].fundAccessLimitGroups = _fundAccessLimitGroupProjectOne;

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = 0;
        _rulesetConfig[0].decayPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroupProjectTwo;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](2);

        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});
        _terminalConfigurations[1] =
            JBTerminalConfig({terminal: _terminal2, accountingContextsToAccept: _tokensToAccept});

        // Dummy project that receive fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _feeProjectRuleset,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testHeldFeeIsProcessedOnMigrate() public {
        // Setup: Pay so we have balance to use
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Setup: use allowance so we incur a fee
        vm.startPrank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeDistLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_projectOwner),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Calculate the fee from the allowance use.
        uint256 _feeAmount =
            _nativeDistLimit - _nativeDistLimit * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);

        uint256 _afterFee = _nativeDistLimit - _feeAmount;

        // Check: Owner balance is accurate (dist - fee) and fee is in the terminal (held but not processed)
        assertEq(_projectOwner.balance, _afterFee);
        assertEq(address(_terminal).balance, _nativeDistLimit + _feeAmount);

        // Send: Migration to terminal2
        _terminal.migrateBalanceOf(_projectId, JBConstants.NATIVE_TOKEN, _terminal2);

        // Check: Held Fee is processed and feeAmount remains in terminal
        assertEq(address(_terminal).balance, _feeAmount);

        vm.stopPrank();
    }

    function testHeldFeeRepaymentWithMigration() public {
        // Setup: Pay so we have balance to use
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Setup: use allowance so we incur a fee
        vm.startPrank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeDistLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_projectOwner),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Calculate the fee from the allowance use.
        uint256 _feeAmount =
            _nativeDistLimit - _nativeDistLimit * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);

        uint256 _afterFee = _nativeDistLimit - _feeAmount;

        // Check: Owner balance is accurate (dist - fee) and fee is in the terminal (held but not processed)
        assertEq(_projectOwner.balance, _afterFee);
        assertEq(address(_terminal).balance, _nativeDistLimit + _feeAmount);

        vm.startPrank(_projectOwner);
        // Setup: addToBalance to reset our held fees
        _terminal.addToBalanceOf{value: _nativeDistLimit - _feeAmount}(
            _projectId, JBConstants.NATIVE_TOKEN, _nativeDistLimit - _feeAmount, true, "forge test", ""
        );

        // Send: Migration to terminal2
        _terminal.migrateBalanceOf(_projectId, JBConstants.NATIVE_TOKEN, _terminal2);

        // Check: Held fee has been repaid, no balance remains.
        assertEq(address(_terminal).balance, 0);

        vm.stopPrank();
    }

    function testHeldFeeUnlockAndProcess() public {
        // Setup: Pay so we have balance to use
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Setup: use allowance so we incur a fee
        vm.startPrank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeDistLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_projectOwner),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Calculate the fee from the allowance use.
        uint256 _feeAmount =
            _nativeDistLimit - _nativeDistLimit * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);

        uint256 _afterFee = _nativeDistLimit - _feeAmount;

        // Check: Owner balance is accurate (dist - fee) and fee is in the terminal (held but not processed)
        assertEq(_projectOwner.balance, _afterFee);
        assertEq(address(_terminal).balance, _nativeDistLimit + _feeAmount);

        // Setup: fast-forward to when fees can be processed
        vm.warp(block.timestamp + 2_419_200);

        // Send: Process the fees
        _terminal.processHeldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);

        // Check: Reflected in terminal
        JBFee[] memory _emptyFee = _terminal.heldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);
        assertEq(_emptyFee.length, 0);
    }

    function testHeldFeeUnlockTooSoon() public {
        // Setup: Pay so we have balance to use
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Setup: use allowance so we incur a fee
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeDistLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_projectOwner),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Calculate the fee from the allowance use.
        uint256 _feeAmount =
            _nativeDistLimit - _nativeDistLimit * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);

        uint256 _afterFee = _nativeDistLimit - _feeAmount;

        // Check: Owner balance is accurate (dist - fee) and fee is in the terminal (held but not processed)
        assertEq(_projectOwner.balance, _afterFee);
        assertEq(address(_terminal).balance, _nativeDistLimit + _feeAmount);

        // Check: Heldfee unlock timestamp
        JBFee[] memory _checkOgFee = _terminal.heldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);
        assertEq(_checkOgFee[0].unlockTimestamp, block.timestamp + 2_419_200);

        // Setup: fast-forward to next block where fee shouldn't process (too early)
        vm.warp(block.timestamp + 1);

        // Send: Fail to process the fees
        _terminal.processHeldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);

        // Check: Fee persists in terminal
        JBFee[] memory _persistingFee = _terminal.heldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);

        // Wher go fee..?
        assertEq(_persistingFee.length, 1);
    }

    function test_AuditFinding4POC() external {
        // TODO: change this to true before merging where fixes are, or when issues are fixed on this PR.
        vm.skip(false);

        // Setup: Pay the zero project so the terminal has balance of 1 eth from another project.
        _terminal.pay{value: 1 ether}({
            projectId: 1,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Setup: Pay project 2 so we have balance to use
        _terminal.pay{value: 1 ether}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        uint256 prevBalance = _projectOwner.balance;

        // Ensure we start with zero balance before payout
        assertEq(prevBalance, 0);

        // Send payout
        // So you don't have to scroll up, _nativeDistAmount = 1 ether.
        _terminal.sendPayoutsOf(
            _projectId,
            JBConstants.NATIVE_TOKEN,
            _nativeDistLimit,
            uint32(uint160(JBConstants.NATIVE_TOKEN)),
            _nativeDistLimit
        );

        // Ensure the payout was successful
        uint256 _feeAmount =
            _nativeDistLimit - _nativeDistLimit * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);
        uint256 _afterFee = _nativeDistLimit - _feeAmount;
        assertEq(_projectOwner.balance, _afterFee);

        // Terminal has accepted 2 pays (totaling 2 eth), payout of nativeDistLimit (1eth) was sent, and fee was taken.
        // So we only have 1 eth and the fee taken left in the terminal.
        assertEq(address(_terminal).balance, _nativeDistLimit + _feeAmount);

        // Check the fee attributes
        JBFee[] memory _checkOgFee = _terminal.heldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);

        // Check the unlock timestamp
        assertEq(_checkOgFee[0].unlockTimestamp, block.timestamp + 2_419_200);

        // Audit Example correctly asserts that the fee amount is 1 ETH
        assertEq(_checkOgFee[0].amount, _nativeDistLimit);

        // Audit Example correctly asserts that the projects balance in terminal store will be zero.
        uint256 project2BalanceStore =
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN);
        assertEq(project2BalanceStore, 0);

        // We continue on with the example, where another project carries a balance (1 eth here).
        uint256 project1BalanceStore = jbTerminalStore().balanceOf(address(_terminal), 1, JBConstants.NATIVE_TOKEN);
        assertEq(project1BalanceStore, 1 ether);

        // Warp to when we can call processHeldFeesOf.
        vm.warp(_checkOgFee[0].unlockTimestamp);

        // Accounting should be incorrectly adjusted for the fee project after the process call.
        uint256 feeProjectBalanceBefore = project1BalanceStore;

        // Process the held fees, which adds 1 ether 'amount' to the fee project.
        _terminal.processHeldFeesOf(_projectId, JBConstants.NATIVE_TOKEN);

        // Reference the balance now (for the fee project).
        uint256 feeProjectBalanceAfter = jbTerminalStore().balanceOf(address(_terminal), 1, JBConstants.NATIVE_TOKEN);

        // Fee project now has a balance of 2 eth even though it has only been paid one eth.
        assertEq(feeProjectBalanceAfter, 2 ether);
        assertGt(feeProjectBalanceAfter, feeProjectBalanceBefore);

        // Pay project 2 again so the terminal holds enough balance for the excess usage via the fee project.
        _terminal.pay{value: 1 ether}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Reference the owner balance before payout.
        uint256 ownerBalanceBefore = _projectOwner.balance;

        // Now we see if we can use the 2 ether minus fees via project 1.
        uint256 paidOutFromProjectOne = _terminal.sendPayoutsOf({
            projectId: 1,
            token: JBConstants.NATIVE_TOKEN,
            amount: 2 ether,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            minTokensPaidOut: 0
        });

        // Calculate the fee from the allowance use.
        uint256 _feeAmount2 = paidOutFromProjectOne
            - paidOutFromProjectOne * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);

        // The payout happens as described in the example.
        uint256 _afterFee2 = paidOutFromProjectOne - _feeAmount2;
        assertEq(_projectOwner.balance - ownerBalanceBefore, _afterFee2);

        // Confirm the total terminal balance < the balance of project 2.
        uint256 balanceOfProject2 =
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN);
        assertLt(address(_terminal).balance, balanceOfProject2);
    }
}
