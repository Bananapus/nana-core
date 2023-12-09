// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Project can issue token, receive payments in exchange for tokens, burn some of the claimed tokens, and allow holders
// to redeem rest of tokens.
contract TestPayBurnRedeemFlow_Local is TestBaseWorkflow {
    IJBController private _controller;
    IJBMultiTerminal private _terminal;
    JBTokens private _tokens;
    JBRulesetData private _data;
    JBRulesetMetadata _metadata;
    uint256 private _projectId;
    address private _projectOwner;
    address private _beneficiary;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _controller = jbController();
        _terminal = jbMultiTerminal();
        _tokens = jbTokens();
        _data = JBRulesetData({duration: 0, weight: 1000 * 10 ** 18, decayRate: 0, hook: JBDeadline(address(0))});
        _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
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

        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = (_terminal);

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].data = _data;
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        // Package up terminal configuration.
        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContextConfig[] memory _accountingContexts = new JBAccountingContextConfig[](1);
        _accountingContexts[0] =
            JBAccountingContextConfig({token: JBConstants.NATIVE_TOKEN, standard: JBTokenStandards.NATIVE});
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextConfigs: _accountingContexts});

        // Dummy project that will receive fees.
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
    }

    function testFuzzPayBurnRedeemFlow(
        uint96 _nativePayAmount,
        uint256 _burnTokenAmount,
        uint256 _redeemTokenAmount
    )
        external
    {
        // Issue an ERC-20 token for project.
        vm.prank(_projectOwner);
        _controller.deployERC20For(_projectId, "TestName", "TestSymbol");

        // Make a payment.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary has a balance of project tokens.
        uint256 _beneficiaryTokenBalance =
            UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_data.weight)));
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the native token balance in terminal is up to date.
        uint256 _terminalBalance = _nativePayAmount;
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _terminalBalance
        );

        // Burn tokens from beneficiary.
        if (_burnTokenAmount == 0) {
            vm.expectRevert(abi.encodeWithSignature("NO_BURNABLE_TOKENS()"));
        } else if (_burnTokenAmount > _beneficiaryTokenBalance) {
            vm.expectRevert(abi.encodeWithSignature("INSUFFICIENT_FUNDS()"));
        } else {
            _beneficiaryTokenBalance = _beneficiaryTokenBalance - _burnTokenAmount;
        }

        vm.prank(_beneficiary);
        _controller.burnTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            tokenCount: _burnTokenAmount,
            memo: "I hate tokens!"
        });

        // Make sure the beneficiary should has a new balance of project tokens.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Redeem tokens.
        if (_redeemTokenAmount > _beneficiaryTokenBalance) {
            vm.expectRevert(abi.encodeWithSignature("INSUFFICIENT_TOKENS()"));
        } else {
            _beneficiaryTokenBalance = _beneficiaryTokenBalance - _redeemTokenAmount;
        }

        vm.prank(_beneficiary);
        uint256 _reclaimAmt = _terminal.redeemTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            count: _redeemTokenAmount,
            minReclaimed: 0,
            beneficiary: payable(_beneficiary),
            metadata: new bytes(0)
        });

        // Make sure the beneficiary has a new balance of project tokens.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the native token balance in terminal is up to date.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _terminalBalance - _reclaimAmt
        );
    }
}
