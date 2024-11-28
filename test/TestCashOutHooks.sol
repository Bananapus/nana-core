// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestCashOutHooks_Local is TestBaseWorkflow {
    using JBRulesetMetadataResolver for JBRuleset;

    uint112 private constant _WEIGHT = 1000 * 10 ** 18;
    address private constant _DATA_HOOK = address(bytes20(keccak256("datahook")));

    IJBController private _controller;
    IJBMultiTerminal private _terminal;
    IJBTokens private _tokens;
    address private _projectOwner;
    address private _beneficiary;

    uint56 _projectId;

    function setUp() public override {
        super.setUp();

        vm.label(_DATA_HOOK, "Data Hook");

        _controller = jbController();
        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _terminal = jbMultiTerminal();
        _tokens = jbTokens();

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
            holdFees: false,
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: true,
            dataHook: _DATA_HOOK,
            metadata: 0
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _WEIGHT;
        _rulesetConfig[0].decayPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        // Create a first project to collect fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        _projectId = uint56(
            _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfig,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            })
        );

        // Issue the project's tokens.
        vm.prank(_projectOwner);
        IJBToken _token = _controller.deployERC20For(_projectId, "TestName", "TestSymbol", bytes32(0));

        // Make sure the project's new project token is set.
        assertEq(address(_tokens.tokenOf(_projectId)), address(_token));
    }
    
    function testCashOutHookWithNoFees() public {
        // Reference and bound pay amount.
        uint256 _nativePayAmount = 10 ether;
        uint256 _halfPaid = 5 ether;

        // Cash out hook address.
        address _cashOutHook = makeAddr("SOFA");
        vm.label(_cashOutHook, "Cash Out Delegate");

        // Keep a reference to the current ruleset.
        (JBRuleset memory _ruleset,) = _controller.currentRulesetOf(_projectId);

        vm.deal(address(this), _nativePayAmount);
        uint256 _beneficiaryTokensReceived = _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: address(this),
            minReturnedTokens: 0,
            memo: "Forge Test",
            metadata: ""
        });

        // Make sure the beneficiary has a balance of project tokens.
        uint256 _beneficiaryTokenBalance =
            UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_WEIGHT)));
        assertEq(_tokens.totalBalanceOf(address(this), _projectId), _beneficiaryTokenBalance);
        assertEq(_beneficiaryTokensReceived, _beneficiaryTokenBalance);

        // Make sure the native token balance in terminal is up to date.
        uint256 _nativeTerminalBalance = _nativePayAmount;
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativeTerminalBalance
        );

        // Reference cash out hook specifications.
        JBCashOutHookSpecification[] memory _specifications = new JBCashOutHookSpecification[](1);

        _specifications[0] =
            JBCashOutHookSpecification({hook: IJBCashOutHook(_cashOutHook), amount: _halfPaid, metadata: ""});

        vm.startPrank(multisig());
        // Set the hook as feeless.
        _terminal.FEELESS_ADDRESSES().setFeelessAddress(_cashOutHook, true);
        vm.stopPrank();

        // Cash out context.
        JBAfterCashOutRecordedContext memory _cashOutContext = JBAfterCashOutRecordedContext({
            holder: address(this),
            projectId: _projectId,
            rulesetId: _ruleset.id,
            cashOutCount: _beneficiaryTokenBalance / 2,
            reclaimedAmount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).decimals,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).currency,
                _halfPaid
            ),
            forwardedAmount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).decimals,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).currency,
                _halfPaid
            ),
            cashOutTaxRate: 0, 
            beneficiary: payable(address(this)),
            hookMetadata: "",
            cashOutMetadata: ""
        });

        // Mock the hook.
        vm.mockCall(
            _cashOutHook,
            abi.encodeWithSelector(IJBCashOutHook.afterCashOutRecordedWith.selector),
            abi.encode(_cashOutContext)
        );

        // Assert that the hook gets called with the expected value.
        vm.expectCall(
            _cashOutHook,
            _halfPaid,
            abi.encodeWithSelector(IJBCashOutHook.afterCashOutRecordedWith.selector, _cashOutContext)
        );

        vm.mockCall(
            _DATA_HOOK,
            abi.encodeWithSelector(IJBRulesetDataHook.beforeCashOutRecordedWith.selector),
            abi.encode(
                _ruleset.cashOutTaxRate(), _beneficiaryTokenBalance / 2, _beneficiaryTokenBalance, _specifications
            )
        );

        _terminal.cashOutTokensOf({
            holder: address(this),
            projectId: _projectId,
            cashOutCount: _beneficiaryTokenBalance / 2,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(address(this)),
            metadata: new bytes(0)
        });
    }

    function testCashOutHookWithFeesAndCustomInfo() public {
        // Reference and bound pay amount.
        uint256 _nativePayAmount = 10 ether;
        uint256 _halfPaid = 5 ether;

        // Cash out hook address.
        address _cashOutHook = makeAddr("SOFA");
        vm.label(_cashOutHook, "Cash Out Delegate");

        // Keep a reference to the current ruleset.
        (JBRuleset memory _ruleset,) = _controller.currentRulesetOf(_projectId);

        vm.deal(address(this), _nativePayAmount);
        uint256 _beneficiaryTokensReceived = _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: address(this),
            minReturnedTokens: 0,
            memo: "Forge Test",
            metadata: ""
        });

        // Make sure the beneficiary has a balance of project tokens.
        uint256 _beneficiaryTokenBalance =
            UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_WEIGHT)));
        assertEq(_tokens.totalBalanceOf(address(this), _projectId), _beneficiaryTokenBalance);
        assertEq(_beneficiaryTokensReceived, _beneficiaryTokenBalance);

        // Make sure the native token balance in terminal is up to date.
        uint256 _nativeTerminalBalance = _nativePayAmount;
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativeTerminalBalance
        );

        // Reference cash out hook specifications.
        JBCashOutHookSpecification[] memory _specifications = new JBCashOutHookSpecification[](1);

        _specifications[0] =
            JBCashOutHookSpecification({hook: IJBCashOutHook(_cashOutHook), amount: _halfPaid, metadata: ""});

        uint256 _customCashOutTaxRate = JBConstants.MAX_CASH_OUT_TAX_RATE / 2;
        uint256 _customCashOutCount = 1 * 10 ** 18;
        uint256 _customTotalSupply = 5 * 10 ** 18;

        uint256 _forwardedAmount =
            _halfPaid - (_halfPaid - mulDiv(_halfPaid, JBConstants.MAX_FEE, _terminal.FEE() + JBConstants.MAX_FEE));

        uint256 _beneficiaryAmount = mulDiv(
            mulDiv(_nativePayAmount, _customCashOutCount, _customTotalSupply),
            (JBConstants.MAX_CASH_OUT_TAX_RATE - _customCashOutTaxRate)
                + mulDiv(_customCashOutCount, _customCashOutTaxRate, _customTotalSupply),
            JBConstants.MAX_CASH_OUT_TAX_RATE
        );

        _beneficiaryAmount -= (
            _beneficiaryAmount - mulDiv(_beneficiaryAmount, JBConstants.MAX_FEE, _terminal.FEE() + JBConstants.MAX_FEE)
        );

        // Cash out context.
        JBAfterCashOutRecordedContext memory _cashOutContext = JBAfterCashOutRecordedContext({
            holder: address(this),
            projectId: _projectId,
            rulesetId: _ruleset.id,
            cashOutCount: _beneficiaryTokenBalance / 2,
            reclaimedAmount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).decimals,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).currency,
                _beneficiaryAmount
            ),
            forwardedAmount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).decimals,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).currency,
                _forwardedAmount
            ),
            cashOutTaxRate: uint16(_customCashOutTaxRate),
            beneficiary: payable(address(this)),
            hookMetadata: "",
            cashOutMetadata: ""
        });

        // Mock the hook.
        vm.mockCall(
            _cashOutHook,
            abi.encodeWithSelector(IJBCashOutHook.afterCashOutRecordedWith.selector),
            abi.encode(_cashOutContext)
        );

        // Assert that the hook gets called with the expected value.
        vm.expectCall(
            _cashOutHook,
            _forwardedAmount,
            abi.encodeWithSelector(IJBCashOutHook.afterCashOutRecordedWith.selector, _cashOutContext)
        );

        vm.mockCall(
            _DATA_HOOK,
            abi.encodeWithSelector(IJBRulesetDataHook.beforeCashOutRecordedWith.selector),
            abi.encode(_customCashOutTaxRate, _customCashOutCount, _customTotalSupply, _specifications)
        );

        _terminal.cashOutTokensOf({
            holder: address(this),
            projectId: _projectId,
            cashOutCount: _beneficiaryTokenBalance / 2,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(address(this)),
            metadata: new bytes(0)
        });
    }

    receive() external payable {}
    fallback() external payable {}
}
