// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

// Projects can issue a token, be paid to receieve claimed tokens,  burn some of the claimed tokens, redeem rest of
// tokens
contract TestRedeem_Local is TestBaseWorkflow {
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
        _data = JBRulesetData({
            duration: 0,
            weight: 1000 * 10 ** 18,
            decayRate: 0,
            hook: IJBRulesetApprovalHook(address(0))
        });
        _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2,
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

        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].data = _data;
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroups = new JBFundAccessLimitGroup[](0);

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContextConfig[] memory _accountingContextConfigs = new JBAccountingContextConfig[](1);
        _accountingContextConfigs[0] =
            JBAccountingContextConfig({token: JBConstants.NATIVE_TOKEN, standard: JBTokenStandards.NATIVE});
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextConfigs: _accountingContextConfigs});

        // Create a first project to collect fees.
        _controller.launchProjectFor({
            owner: address(420), // Random.
            projectMetadata: "whatever",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations, // Set terminals to receive fees.
            memo: ""
        });

        // Create the project to test.
        _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectMetadata: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testRedeem(uint256 _tokenAmountToRedeem) external {
        uint96 _nativePayAmount = 10 ether;

        // Issue the project's tokens.
        vm.prank(_projectOwner);
        _controller.deployERC20For(_projectId, "TestName", "TestSymbol");

        // Pay the project.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
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
        uint256 _nativeTerminalBalance = _nativePayAmount;
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativeTerminalBalance
        );

        // Fuzz 1 to full balance redemption.
        _tokenAmountToRedeem = bound(_tokenAmountToRedeem, 1, _beneficiaryTokenBalance);

        // Test: redeem.
        vm.prank(_beneficiary);
        uint256 _nativeReclaimAmt = _terminal.redeemTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            token: JBConstants.NATIVE_TOKEN,
            count: _tokenAmountToRedeem,
            minReclaimed: 0,
            beneficiary: payable(_beneficiary),
            metadata: new bytes(0)
        });

        // Keep a reference to the expected amount redeemed.
        uint256 _grossRedeemed = mulDiv(
            mulDiv(_nativeTerminalBalance, _tokenAmountToRedeem, _beneficiaryTokenBalance),
            _metadata.redemptionRate
                + mulDiv(
                    _tokenAmountToRedeem,
                    JBConstants.MAX_REDEMPTION_RATE - _metadata.redemptionRate,
                    _beneficiaryTokenBalance
                ),
            JBConstants.MAX_REDEMPTION_RATE
        );

        // Compute the fee taken.
        uint256 _fee = _grossRedeemed - mulDiv(_grossRedeemed, 1_000_000_000, 25_000_000 + 1_000_000_000); // 2.5% fee

        // Compute the net amount received, still in project.
        uint256 _netReceived = _grossRedeemed - _fee;

        // Make sure the correct amount was returned (2 wei precision).
        assertApproxEqAbs(_nativeReclaimAmt, _netReceived, 2, "incorrect amount returned");

        // Make sure the beneficiary received correct amount of native tokens.
        assertEq(payable(_beneficiary).balance, _nativeReclaimAmt);

        // Make sure the beneficiary has correct amount of tokens.
        assertEq(
            _tokens.totalBalanceOf(_beneficiary, _projectId),
            _beneficiaryTokenBalance - _tokenAmountToRedeem,
            "incorrect beneficiary balance"
        );

        // Make sure the native token balance in terminal should be up to date (with 1 wei precision).
        assertApproxEqAbs(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativeTerminalBalance - _nativeReclaimAmt - (_nativeReclaimAmt * 25 / 1000),
            1
        );
    }
}
