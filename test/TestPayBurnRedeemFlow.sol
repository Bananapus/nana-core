// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Project can issue token, receive payments in exchange for tokens, burn some of the claimed tokens, and allow holders
// to redeem rest of tokens.
contract TestPayBurnRedeemFlow_Local is TestBaseWorkflow {
    IJBController private _controller;
    IJBMultiTerminal private _terminal;
    JBTokens private _tokens;
    uint112 private _weight;
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
        _weight = 1000 * 10 ** 18;
        _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: true,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
            allowSetController: false,
            allowAddAccountingContext: true,
            allowAddPriceFeed: false,
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
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].decayPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        // Package up terminal configuration.
        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

        // Dummy project that will receive fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
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

    function testFuzzPayBurnRedeemFlow(
        uint112 _nativePayAmount,
        uint256 _burnTokenAmount,
        uint256 _redeemTokenAmount
    )
        external
    {
        // Issue an ERC-20 token for project.
        vm.prank(_projectOwner);
        _controller.deployERC20For(_projectId, "TestName", "TestSymbol", bytes32(0));

        address someRandomUser = vm.addr(1);
        vm.prank(someRandomUser);
        vm.deal(someRandomUser, _nativePayAmount);
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
            UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_weight)));
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the native token balance in terminal is up to date.
        uint256 _terminalBalance = _nativePayAmount;
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _terminalBalance
        );

        // Burn tokens from beneficiary.
        if (_burnTokenAmount == 0) {
            vm.expectRevert(JBController.JBController_NoBurnableTokens.selector);
        } else if (_burnTokenAmount > _beneficiaryTokenBalance) {
            vm.expectRevert(JBTokens.JBTokens_InsufficientFunds.selector);
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
            vm.expectRevert(JBTerminalStore.JBTerminalStore_InsufficientTokens.selector);
        } else {
            _beneficiaryTokenBalance = _beneficiaryTokenBalance - _redeemTokenAmount;
        }

        vm.prank(_beneficiary);
        uint256 _reclaimAmt = _terminal.redeemTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            tokenToReclaim: JBConstants.NATIVE_TOKEN, // Unused.
            redeemCount: _redeemTokenAmount,
            minTokensReclaimed: 0,
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
