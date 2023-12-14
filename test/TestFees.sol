// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Projects can be launched.
contract TestFees_Local is TestBaseWorkflow {
    IJBController private _controller;
    JBRulesetData private _data;
    JBRulesetMetadata private _metadata;
    JBRulesetMetadata private _feeProjectMetadata;
    IJBMultiTerminal private _terminal;
    IJBMultiTerminal private _terminal2;
    IJBRulesets private _rulesets;

    uint256 _nativePayAmount;
    uint256 _nativeDistLimit;

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

        _data = JBRulesetData({duration: 0, weight: 0, decayRate: 0, hook: IJBRulesetApprovalHook(address(0))});

        _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: true,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: true,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        _feeProjectMetadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: true,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeDistLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeDistLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].data = _data;
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _feeProjectRuleset = new JBRulesetConfig[](1);
        _feeProjectRuleset[0].mustStartAtOrAfter = 0;
        _feeProjectRuleset[0].data = _data;
        _feeProjectRuleset[0].metadata = _feeProjectMetadata;
        _feeProjectRuleset[0].splitGroups = new JBSplitGroup[](0);
        _feeProjectRuleset[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](2);

        address[] memory _tokensToAccept = new address[](1);
        _tokensToAccept[0] = JBConstants.NATIVE_TOKEN;

        _terminalConfigurations[0] = JBTerminalConfig({terminal: _terminal, tokensToAccept: _tokensToAccept});
        _terminalConfigurations[1] = JBTerminalConfig({terminal: _terminal2, tokensToAccept: _tokensToAccept});

        // Dummy project that receive fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectMetadata: "myIPFSHash",
            rulesetConfigurations: _feeProjectRuleset,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectMetadata: "myIPFSHash",
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
            minReturnedTokens: 0,
            beneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Calculate the fee from the allowance use.
        uint256 _feeAmount =
            _nativeDistLimit - _nativeDistLimit * JBConstants.MAX_FEE / (_terminal.FEE() + JBConstants.MAX_FEE);

        uint256 _afterFee = _nativeDistLimit - _feeAmount;

        assertEq(_projectOwner.balance, _afterFee);

        // Setup: addToBalance to reset our held fees
        _terminal.addToBalanceOf{value: _nativeDistLimit - _feeAmount}(_projectId, JBConstants.NATIVE_TOKEN, _nativeDistLimit - _feeAmount, true, "forge test", "");
        
        // Send: Migration to terminal2
        _terminal.migrateBalanceOf(_projectId, JBConstants.NATIVE_TOKEN, _terminal2);

        // Check: Fee amount shouldnt remain in terminal 1 since it was repaid
        assertEq(address(_terminal).balance, 0);

        vm.stopPrank();
    }
}