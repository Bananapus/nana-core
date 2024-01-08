// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestRedeemHooks_Local is TestBaseWorkflow {
    uint256 private constant _WEIGHT = 1000 * 10 ** 18;
    address private constant _DATA_HOOK = address(bytes20(keccak256("datahook")));

    IJBController private _controller;
    IJBMultiTerminal private _terminal;
    IJBTokens private _tokens;
    address private _projectOwner;
    address private _beneficiary;

    uint256 _projectId;

    function setUp() public override {
        super.setUp();

        vm.label(_DATA_HOOK, "Data Hook");

        _controller = jbController();
        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _terminal = jbMultiTerminal();
        _tokens = jbTokens();

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: true,
            dataHook: _DATA_HOOK,
            metadata: 0
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _WEIGHT;
        _rulesetConfig[0].decayRate = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        address[] memory _tokensToAccept = new address[](1);
        _tokensToAccept[0] = JBConstants.NATIVE_TOKEN;
        _terminalConfigurations[0] = JBTerminalConfig({terminal: _terminal, tokensToAccept: _tokensToAccept});

        // Create a first project to collect fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectMetadata: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
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

        // Issue the project's tokens.
        vm.prank(_projectOwner);
        IJBToken _token = _controller.deployERC20For(_projectId, "TestName", "TestSymbol");

        // Make sure the project's new project token is set.
        assertEq(address(_tokens.tokenOf(_projectId)), address(_token));
    }

    function testRedeemHook() public {
        // Reference and bound pay amount.
        uint256 _nativePayAmount = 10 ether;
        uint256 _halfPaid = 5 ether;

        // Redeem hook address.
        address _redeemHook = makeAddr("SOFA");
        vm.label(_redeemHook, "Redemption Delegate");

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
        emit log_uint(_beneficiaryTokenBalance);

        // Make sure the native token balance in terminal is up to date.
        uint256 _nativeTerminalBalance = _nativePayAmount;
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativeTerminalBalance
        );

        // Reference redeem hook specifications.
        JBRedeemHookSpecification[] memory _specifications = new JBRedeemHookSpecification[](1);

        _specifications[0] =
            JBRedeemHookSpecification({hook: IJBRedeemHook(_redeemHook), amount: _halfPaid, metadata: ""});

        // Redeem context.
        JBAfterRedeemRecordedContext memory _redeemContext = JBAfterRedeemRecordedContext({
            holder: address(this),
            projectId: _projectId,
            rulesetId: _ruleset.id,
            redeemCount: _beneficiaryTokenBalance / 2,
            reclaimedAmount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN,
                _halfPaid,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).decimals,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).currency
                ),
            forwardedAmount: JBTokenAmount(
                JBConstants.NATIVE_TOKEN,
                _halfPaid,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).decimals,
                _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN).currency
                ),
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            beneficiary: payable(address(this)),
            hookMetadata: "",
            redeemerMetadata: ""
        });

        // Mock the hook.
        vm.mockCall(
            _redeemHook,
            abi.encodeWithSelector(IJBRedeemHook.afterRedeemRecordedWith.selector),
            abi.encode(_redeemContext)
        );

        // Assert that the hook gets called with the expected value.
        vm.expectCall(
            _redeemHook,
            _halfPaid,
            abi.encodeWithSelector(IJBRedeemHook.afterRedeemRecordedWith.selector, _redeemContext)
        );

        vm.mockCall(
            _DATA_HOOK,
            abi.encodeWithSelector(IJBRulesetDataHook.beforeRedeemRecordedWith.selector),
            abi.encode(_halfPaid, _specifications)
        );

        _terminal.redeemTokensOf({
            holder: address(this),
            projectId: _projectId,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            redeemCount: _beneficiaryTokenBalance / 2,
            minTokensReclaimed: 0,
            beneficiary: payable(address(this)),
            metadata: new bytes(0)
        });
    }

    receive() external payable {}
    fallback() external payable {}
}
