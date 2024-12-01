// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestSplits_Local is TestBaseWorkflow {
    IJBController private _controller;
    JBRulesetMetadata private _metadata;
    IJBMultiTerminal private _terminal;
    IJBTokens private _tokens;
    uint112 private _weight;

    address private _projectOwner;
    address payable private _splitsGuy;
    uint256 private _projectId;
    uint224 _nativePayoutLimit = 4 ether;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _terminal = jbMultiTerminal();
        _controller = jbController();
        _tokens = jbTokens();
        _splitsGuy = payable(makeAddr("guy"));
        _weight = 1000 * 10 ** 18;

        _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
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

        // Instantiate split parameters.
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](3);
        JBSplit[] memory _splits = new JBSplit[](2);
        JBSplit[] memory _reserveRateSplits = new JBSplit[](1);

        // Set up a payout split recipient.
        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: 0,
            beneficiary: _splitsGuy,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // A dummy used to check that splits groups of "0" cannot bypass payout limits.
        _splits[1] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT / 2,
            projectId: 0,
            beneficiary: _splitsGuy,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: uint32(uint160(JBConstants.NATIVE_TOKEN)), splits: _splits});

        // A dummy used to check that splits groups of "0" cannot bypass payout limits.
        _splitsGroup[1] = JBSplitGroup({groupId: 0, splits: _splits});

        // Configure a reserve rate split recipient.
        _reserveRateSplits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: 0,
            beneficiary: _splitsGuy,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // Reserved rate split group.
        _splitsGroup[2] = JBSplitGroup({groupId: JBSplitGroupIds.RESERVED_TOKENS, splits: _reserveRateSplits});

        // Package up fund access limits.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);

        _payoutLimits[0] =
            JBCurrencyAmount({amount: _nativePayoutLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});
        _surplusAllowances[0] = JBCurrencyAmount({amount: 2 ether, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});
        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(_terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitsGroup;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

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

        // Dummy project to receive fees.
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

    function testSplitPayoutAndReservedPercentSplit() public {
        uint256 _nativePayAmount = 10 ether;
        address _payee = makeAddr("payee");
        vm.deal(_payee, _nativePayAmount);
        vm.prank(_payee);

        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _payee,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });

        // First payout meets our native token payout limit.
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativePayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN, // Unused.
            minTokensPaidOut: 0
        });

        // Calculate the amount returned after fees are processed.
        uint256 _beneficiaryNativeBalance =
            mulDiv(_nativePayoutLimit, JBConstants.MAX_FEE, JBConstants.MAX_FEE + _terminal.FEE());

        assertEq(_splitsGuy.balance, _beneficiaryNativeBalance);

        // Check that split groups of "0" don't extend the payout limit (keeping this out of a number test, for
        // brevity).
        vm.expectRevert(
            abi.encodeWithSelector(
                JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector,
                _nativePayoutLimit * 2,
                _nativePayoutLimit
            )
        );

        // First payout meets our native token payout limit.
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativePayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN, // Unused.
            minTokensPaidOut: 0
        });

        vm.prank(_projectOwner);
        _controller.sendReservedTokensToSplitsOf(_projectId);

        // 10 native tokens paid -> 1000 per Eth, 10000 total, 50% reserve rate, 5000 tokens sent.
        uint256 _reserveRateDistributionAmount =
            mulDiv(_nativePayAmount, _weight, 10 ** 18) * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;

        assertEq(_tokens.totalBalanceOf(_splitsGuy, _projectId), _reserveRateDistributionAmount);
    }

    function testReservedPercentSplitTerminal_reverts() public {
        uint256 _amount = 100 ether;
        uint56 _mockProjectId = 9_999_999;
        address _mockTerminal = address(88_888_888);
        JBSplit[] memory _reserveRateSplits = new JBSplit[](1);

        // Configure a reserve rate split recipient.
        _reserveRateSplits[0] = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _mockProjectId,
            beneficiary: _splitsGuy,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](1);
        _splitsGroup[0] = JBSplitGroup({groupId: JBSplitGroupIds.RESERVED_TOKENS, splits: _reserveRateSplits});

        _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT,
            redemptionRate: 0,
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
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitsGroup;

        // Create a new project.
        _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: new JBTerminalConfig[](0),
            memo: ""
        });

        // Deploy the token.
        vm.startPrank(_projectOwner);
        IERC20Metadata _token =
            IERC20Metadata(address(_controller.deployERC20For(_projectId, "Token", "Token", bytes32(0))));

        // Mint tokens with reservedPercent enabled.
        _controller.mintTokensOf({
            projectId: _projectId,
            tokenCount: _amount,
            beneficiary: _projectOwner,
            memo: "",
            useReservedPercent: true
        });

        // Mock the primary terminal of the mock project.
        vm.mockCall({
            callee: address(jbDirectory()),
            msgValue: 0,
            data: abi.encodeCall(IJBDirectory.primaryTerminalOf, (_mockProjectId, address(_token))),
            returnData: abi.encode(_mockTerminal)
        });

        // Make it revert on payment.
        vm.mockCallRevert({callee: _mockTerminal, data: abi.encode(IJBTerminal.pay.selector), revertData: ""});

        // Distribute the tokens to the reverting terminal.
        _controller.sendReservedTokensToSplitsOf(_projectId);

        // Assert that the terminal does *NOT* have any allowance.
        assertEq(_token.allowance(address(_controller), address(_mockTerminal)), 0);

        // Assert that the beneficiary did receive the tokens.
        assertEq(_token.balanceOf(_splitsGuy), _amount);
    }

    function testFuzzedSplitParameters(uint32 _currencyId, uint256 _multiplier) public {
        _multiplier = bound(_multiplier, 2, JBConstants.SPLITS_TOTAL_PERCENT);

        // Instantiate split parameters.
        JBSplitGroup[] memory _splitsGroup = new JBSplitGroup[](2);
        JBSplit[] memory _splits = new JBSplit[](2);

        // Set up a payout split recipient.
        _splits[0] = JBSplit({
            preferAddToBalance: false,
            percent: uint32(JBConstants.SPLITS_TOTAL_PERCENT / _multiplier),
            projectId: 0,
            beneficiary: _splitsGuy,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        // A dummy used to check that splits groups of "0" don't bypass payout limits.
        _splits[1] = JBSplit({
            preferAddToBalance: false,
            percent: uint32(JBConstants.SPLITS_TOTAL_PERCENT / _multiplier),
            projectId: 0,
            beneficiary: _splitsGuy,
            lockedUntil: 0,
            hook: IJBSplitHook(address(0))
        });

        _splitsGroup[0] = JBSplitGroup({groupId: _currencyId, splits: _splits});

        // Package up fund access limits.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);

        _payoutLimits[0] = JBCurrencyAmount({amount: _nativePayoutLimit, currency: _currencyId});
        _surplusAllowances[0] = JBCurrencyAmount({amount: 2 ether, currency: _currencyId});
        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(_terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        // Package up ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitsGroup;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

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

        // Dummy project to receive fees.
        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }
}
