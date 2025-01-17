// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import {MockPriceFeed} from "./mock/MockPriceFeed.sol";
import {MaliciousAllowanceBeneficiary, MaliciousPayoutBeneficiary} from "./mock/MockMaliciousBeneficiary.sol";

/// Funds can be accessed in three ways:
/// 1. project owners set a payout limit to prioritize spending to pre-determined destinations. funds being removed from
/// the protocol incurs fees unless the recipients are feeless addresses.
/// 2. project owners set a surplus allowance to allow spending funds from the project's surplus balance in the terminal
/// (i.e. the balance in excess of their payout limit). incurs fees unless the caller is a feeless address.
/// 3. token holders can cash out tokens to access surplus funds. incurs fees if the cash out tax rate != 100%, unless
/// the
/// beneficiary is a feeless address.
/// Each of these only incurs protocol fees if the `_FEE_PROJECT_ID` (project with ID #1) accepts the token being
/// accessed.
contract TestAccessToFunds_Local is TestBaseWorkflow {
    uint256 private constant _FEE_PROJECT_ID = 1;
    uint8 private constant _WEIGHT_DECIMALS = 18; // FIXED
    uint8 private constant _NATIVE_DECIMALS = 18; // FIXED
    uint8 private constant _PRICE_FEED_DECIMALS = 10;
    uint256 private constant _USD_PRICE_PER_NATIVE = 2000 * 10 ** _PRICE_FEED_DECIMALS; // 2000 USDC == 1 native token

    IJBController private _controller;
    IJBPrices private _prices;
    IJBMultiTerminal private _terminal;
    IJBMultiTerminal private _terminal2;
    IJBTokens private _tokens;
    address private _projectOwner;
    address private _beneficiary;
    MockERC20 private _usdcToken;
    uint256 private _projectId;

    uint112 private _weight;
    JBRulesetMetadata private _metadata;

    function setUp() public override {
        super.setUp();

        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _usdcToken = usdcToken();
        _tokens = jbTokens();
        _controller = jbController();
        _prices = jbPrices();
        _terminal = jbMultiTerminal();
        _terminal2 = jbMultiTerminal2();
        _weight = uint112(1000 * 10 ** _WEIGHT_DECIMALS);

        _metadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT / 2, //50%
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2, //50%
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
            allowAddPriceFeed: true,
            holdFees: false,
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });
    }

    // Tests that basic payout limit and surplus allowance limits work as intended.

    function testNativeAllowance() public {
        // Hardcode values to use.
        uint224 _nativeCurrencyPayoutLimit = uint224(10 * 10 ** _NATIVE_DECIMALS);
        uint224 _nativeCurrencySurplusAllowance = uint224(5 * 10 ** _NATIVE_DECIMALS);

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        {
            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

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
                owner: address(420), // Random.
                projectUri: "whatever",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations, // Set terminals to receive fees.
                memo: ""
            });

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Get a reference to the amount being paid.
        // The amount being paid is the payout limit plus two times the surplus allowance.
        uint256 _nativePayAmount = _nativeCurrencyPayoutLimit + (2 * _nativeCurrencySurplusAllowance);

        // Pay the project such that the `_beneficiary` receives project tokens.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens.
        uint256 _beneficiaryTokenBalance = mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );

        // Use the full surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Make sure the beneficiary received the funds and that they are no longer in the terminal.
        uint256 _beneficiaryNativeBalance = _nativeCurrencySurplusAllowance
            - mulDiv(_nativeCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
        assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativePayAmount - _nativeCurrencySurplusAllowance
        );

        // Make sure the fee was paid correctly.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
            _nativeCurrencySurplusAllowance - _beneficiaryNativeBalance
        );
        assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

        // Make sure the project owner got the expected number of tokens.
        assertEq(
            _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
            mulDiv(_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance, _weight, 10 ** _NATIVE_DECIMALS)
                * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT
        );

        // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project owner.
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativeCurrencyPayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0
        });

        // Make sure the project owner received the funds which were paid out.
        uint256 _projectOwnerNativeBalance =
            _nativeCurrencyPayoutLimit - _nativeCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;

        // Make sure the project owner received the full amount.
        assertEq(_projectOwner.balance, _projectOwnerNativeBalance);

        // Make sure the fee was paid correctly.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
            (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance)
        );
        assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance);

        // Make sure the project owner got the expected number of tokens.
        assertEq(
            _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
            mulDiv(
                (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                    + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance),
                _weight,
                10 ** _NATIVE_DECIMALS
            ) * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT
        );

        // Cash out native tokens from the surplus using all of the `_beneficiary`'s tokens.
        vm.prank(_beneficiary);
        _terminal.cashOutTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            cashOutCount: _beneficiaryTokenBalance,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(_beneficiary),
            metadata: new bytes(0)
        });

        // Make sure the beneficiary doesn't have any project tokens left.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), 0);

        // Get the expected amount of native tokens reclaimed by the cash out.
        uint256 _nativeReclaimAmount = mulDiv(
            mulDiv(
                _nativePayAmount - _nativeCurrencySurplusAllowance - _nativeCurrencyPayoutLimit,
                _beneficiaryTokenBalance,
                mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            ),
            _metadata.cashOutTaxRate
                + mulDiv(
                    _beneficiaryTokenBalance,
                    JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                    mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
                ),
            JBConstants.MAX_CASH_OUT_TAX_RATE
        );

        // Calculate the fee from the cash out.
        uint256 _feeAmount = _nativeReclaimAmount * _terminal.FEE() / JBConstants.MAX_FEE;
        assertEq(_beneficiary.balance, _beneficiaryNativeBalance + _nativeReclaimAmount - _feeAmount);

        // Make sure the fee was paid correctly.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
            (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance) + _feeAmount
        );
        assertEq(
            address(_terminal).balance,
            _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                - (_nativeReclaimAmount - _feeAmount)
        );

        // Make sure the project owner got the expected number of the fee project's tokens by paying the fee.
        assertEq(
            _tokens.totalBalanceOf(_beneficiary, _FEE_PROJECT_ID),
            mulDiv(_feeAmount, _weight, 10 ** _NATIVE_DECIMALS) * _metadata.reservedPercent
                / JBConstants.MAX_RESERVED_PERCENT
        );
    }

    function testFuzzNativeAllowance(
        uint224 _nativeCurrencySurplusAllowance,
        uint224 _nativeCurrencyPayoutLimit,
        uint256 _nativePayAmount
    )
        public
    {
        // Make sure the amount of native tokens to pay is bounded.
        _nativePayAmount = bound(_nativePayAmount, 0, 1_000_000 * 10 ** _NATIVE_DECIMALS);

        // Make sure the values don't overflow the registry.
        unchecked {
            vm.assume(
                _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencySurplusAllowance
                    && _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencyPayoutLimit
            );
        }

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        {
            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

            JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
            JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
            _tokensToAccept[0] = JBAccountingContext({
                token: JBConstants.NATIVE_TOKEN,
                decimals: 18,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _terminalConfigurations[0] =
                JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

            // Create a project to collect fees.
            _controller.launchProjectFor({
                owner: address(420), // Random.
                projectUri: "whatever",
                rulesetConfigurations: _rulesetConfigurations, // Use the same ruleset configurations.
                terminalConfigurations: _terminalConfigurations, // set the terminals where fees will be received
                memo: ""
            });

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Make a payment to the test project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens.
        uint256 _beneficiaryTokenBalance = mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );

        // Revert if there's no surplus allowance.
        if (_nativeCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
            // Revert if there's no surplus, or if too much is being withdrawn.
        } else if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencySurplusAllowance,
                    _nativeCurrencyPayoutLimit > _nativePayAmount ? 0 : _nativePayAmount - _nativeCurrencyPayoutLimit
                )
            );
        }

        // Use the full surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Keep a reference to the beneficiary's balance.
        uint256 _beneficiaryNativeBalance;

        // Check the collected balance if one is expected.
        if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit <= _nativePayAmount) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryNativeBalance = _nativeCurrencySurplusAllowance
                - mulDiv(_nativeCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _nativeCurrencySurplusAllowance
            );

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                _nativeCurrencySurplusAllowance - _beneficiaryNativeBalance
            );
            assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

            // Make sure the beneficiary got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                mulDiv(_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance, _weight, 10 ** _NATIVE_DECIMALS)
                    * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT
            );
        } else {
            // Set the native token surplus allowance to 0 if it wasn't used.
            _nativeCurrencySurplusAllowance = 0;
        }

        // Revert if the payout limit is greater than the balance.
        if (_nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencyPayoutLimit,
                    _nativePayAmount
                )
            );

            // Revert if there's no payout limit.
        } else if (_nativeCurrencyPayoutLimit == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0)
            );
        }

        // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project owner.
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativeCurrencyPayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0
        });

        uint256 _projectOwnerNativeBalance;

        // Check the payout if one is expected.
        if (_nativeCurrencyPayoutLimit <= _nativePayAmount && _nativeCurrencyPayoutLimit != 0) {
            // Make sure the project owner received the payout.
            _projectOwnerNativeBalance =
                _nativeCurrencyPayoutLimit - _nativeCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;
            assertEq(_projectOwner.balance, _projectOwnerNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _nativeCurrencySurplusAllowance - _nativeCurrencyPayoutLimit
            );

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                    + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance)
            );
            assertEq(
                address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
            );

            // Make sure the project owner got the expected number of the fee project's tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                mulDiv(
                    (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                        + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance),
                    _weight,
                    10 ** _NATIVE_DECIMALS
                ) * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT
            );
        }

        // Reclaim native tokens from the surplus by cashing out all of the `_beneficiary`'s tokens.
        vm.prank(_beneficiary);
        _terminal.cashOutTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            cashOutCount: _beneficiaryTokenBalance,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(_beneficiary),
            metadata: new bytes(0)
        });

        // Make sure the beneficiary doesn't have tokens left.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), 0);

        // Check for a new beneficiary balance if one is expected.
        if (_nativePayAmount > _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit) {
            // Get the expected amount reclaimed.
            uint256 _nativeReclaimAmount = mulDiv(
                mulDiv(
                    _nativePayAmount - _nativeCurrencySurplusAllowance - _nativeCurrencyPayoutLimit,
                    _beneficiaryTokenBalance,
                    mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
                ),
                _metadata.cashOutTaxRate
                    + mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                        mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
                    ),
                JBConstants.MAX_CASH_OUT_TAX_RATE
            );
            // Calculate the fee from the cash out.
            uint256 _feeAmount = _nativeReclaimAmount * _terminal.FEE() / JBConstants.MAX_FEE;
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance + _nativeReclaimAmount - _feeAmount);

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                    + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance) + _feeAmount
            );
            assertEq(
                address(_terminal).balance,
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                    - (_nativeReclaimAmount - _feeAmount)
            );

            // Make sure the project owner got the expected number of tokens from the fee.
            assertEq(
                _tokens.totalBalanceOf(_beneficiary, _FEE_PROJECT_ID),
                mulDiv(_feeAmount, _weight, 10 ** _NATIVE_DECIMALS) * _metadata.reservedPercent
                    / JBConstants.MAX_RESERVED_PERCENT
            );
        }
    }

    function testFuzzNativeAllowanceWithRevertingFeeProject(
        uint224 _nativeCurrencySurplusAllowance,
        uint224 _nativeCurrencyPayoutLimit,
        uint256 _nativePayAmount,
        bool _feeProjectAcceptsToken
    )
        public
    {
        // Make sure the amount of native tokens to pay is bounded.
        _nativePayAmount = bound(_nativePayAmount, 0, 1_000_000 * 10 ** _NATIVE_DECIMALS);

        // Make sure the values don't overflow the registry.
        unchecked {
            vm.assume(
                _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencySurplusAllowance
                    && _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencyPayoutLimit
            );
        }

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        {
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
                owner: address(420), // Random.
                projectUri: "whatever",
                rulesetConfigurations: new JBRulesetConfig[](0), // No ruleset config will force revert when paid.
                // Set the fee collecting terminal's native token accounting context if the test calls for doing so.
                terminalConfigurations: _feeProjectAcceptsToken ? _terminalConfigurations : new JBTerminalConfig[](0), // Set
                    // terminals to receive fees.
                memo: ""
            });

            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Make a payment to the project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens.
        uint256 _beneficiaryTokenBalance = mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );

        // Revert if there's no surplus allowance.
        if (_nativeCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
            // Revert if there's no surplus, or if too much is being withdrawn.
        } else if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencySurplusAllowance,
                    _nativeCurrencyPayoutLimit > _nativePayAmount ? 0 : _nativePayAmount - _nativeCurrencyPayoutLimit
                )
            );
        }

        // Use the full surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Keep a reference to the beneficiary's balance.
        uint256 _beneficiaryNativeBalance;

        // Check the collected balance if one is expected.
        if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit <= _nativePayAmount) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryNativeBalance = _nativeCurrencySurplusAllowance
                - mulDiv(_nativeCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
            // Make sure the fee stays in the terminal.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _beneficiaryNativeBalance
            );

            // Make sure the fee was not taken.
            assertEq(jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN), 0);
            assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

            // Make sure the beneficiary got no tokens.
            assertEq(_tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID), 0);
        } else {
            // Set the native token's surplus allowance to 0 if it wasn't used.
            _nativeCurrencySurplusAllowance = 0;
        }

        // Revert if the payout limit is greater than the balance.
        if (_nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencyPayoutLimit,
                    _nativePayAmount
                )
            );

            // Revert if there's no payout limit.
        } else if (_nativeCurrencyPayoutLimit == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0)
            );
        }

        // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project owner.
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativeCurrencyPayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0
        });

        uint256 _projectOwnerNativeBalance;

        // Check the received payout if one is expected.
        if (_nativeCurrencyPayoutLimit <= _nativePayAmount && _nativeCurrencyPayoutLimit != 0) {
            // Make sure the project owner received the funds that were paid out.
            _projectOwnerNativeBalance =
                _nativeCurrencyPayoutLimit - _nativeCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;
            assertEq(_projectOwner.balance, _projectOwnerNativeBalance);
            // Make sure the fee stays in the terminal.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
            );

            // Make sure the fee was paid correctly.
            assertEq(jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN), 0);
            assertEq(
                address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
            );

            // Make sure the project owner got the expected number of tokens.
            assertEq(_tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID), 0);
        }

        // Reclaim native tokens from the surplus by cashing out all of the `_beneficiary`'s tokens.
        vm.prank(_beneficiary);
        _terminal.cashOutTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            cashOutCount: _beneficiaryTokenBalance,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(_beneficiary),
            metadata: new bytes(0)
        });

        // Make sure the beneficiary doesn't have tokens left.
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), 0);

        // Check for a new beneficiary balance if one is expected.
        if (_nativePayAmount > _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit) {
            // Get the expected amount reclaimed.
            uint256 _nativeReclaimAmount = mulDiv(
                mulDiv(
                    _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance,
                    _beneficiaryTokenBalance,
                    mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
                ),
                _metadata.cashOutTaxRate
                    + mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                        mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
                    ),
                JBConstants.MAX_CASH_OUT_TAX_RATE
            );

            // Calculate the fee from the cash out.
            uint256 _feeAmount = _nativeReclaimAmount * _terminal.FEE() / JBConstants.MAX_FEE;
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance + _nativeReclaimAmount - _feeAmount);
            // Make sure the fee stays in the terminal.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                    - (_nativeReclaimAmount - _feeAmount)
            );

            // Make sure the fee was paid correctly.
            assertEq(jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN), 0);
            assertEq(
                address(_terminal).balance,
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                    - (_nativeReclaimAmount - _feeAmount)
            );

            // Make sure the project owner got the expected number of tokens from the fee.
            assertEq(_tokens.totalBalanceOf(_beneficiary, _FEE_PROJECT_ID), 0);
        }
    }

    function testFuzzNativeTokenAllowanceForTheFeeProject(
        uint224 _nativeCurrencySurplusAllowance,
        uint224 _nativeCurrencyPayoutLimit,
        uint256 _nativePayAmount
    )
        public
    {
        // Make sure the amount of native tokens to pay is bounded.
        _nativePayAmount = bound(_nativePayAmount, 0, 1_000_000 * 10 ** _NATIVE_DECIMALS);

        // Make sure the values don't overflow the registry.
        unchecked {
            vm.assume(
                _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencySurplusAllowance
                    && _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencyPayoutLimit
            );
        }

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        {
            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

            JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
            JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
            _tokensToAccept[0] = JBAccountingContext({
                token: JBConstants.NATIVE_TOKEN,
                decimals: 18,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _terminalConfigurations[0] =
                JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Make a payment to the project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens.
        uint256 _beneficiaryTokenBalance = mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );

        // Revert if there's no surplus allowance.
        if (_nativeCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
            // Revert if there's no surplus, or if too much is being withdrawn.
        } else if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencySurplusAllowance,
                    _nativeCurrencyPayoutLimit > _nativePayAmount ? 0 : _nativePayAmount - _nativeCurrencyPayoutLimit
                )
            );
        }

        // Use the full surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Keep a reference to the beneficiary's balance.
        uint256 _beneficiaryNativeBalance;

        // Check the collected balance if one is expected.
        if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit <= _nativePayAmount) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryNativeBalance = _nativeCurrencySurplusAllowance
                - mulDiv(_nativeCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _beneficiaryNativeBalance
            );
            assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

            // Make sure the beneficiary got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                mulDiv(_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance, _weight, 10 ** _NATIVE_DECIMALS)
                    * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT
            );
        } else {
            // Set the native token surplus allowance to 0 if it wasn't used.
            _nativeCurrencySurplusAllowance = 0;
        }

        // Revert if the payout limit is greater than the balance.
        if (_nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencyPayoutLimit,
                    _nativePayAmount
                )
            );

            // Revert if there's no payout limit.
        } else if (_nativeCurrencyPayoutLimit == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0)
            );
        }

        // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project owner.
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativeCurrencyPayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0
        });

        uint256 _projectOwnerNativeBalance;

        // Check the received payout if one is expected.
        if (_nativeCurrencyPayoutLimit <= _nativePayAmount && _nativeCurrencyPayoutLimit != 0) {
            // Make sure the project owner received the funds that were paid out.
            _projectOwnerNativeBalance =
                _nativeCurrencyPayoutLimit - _nativeCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;
            assertEq(_projectOwner.balance, _projectOwnerNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
            );
            assertEq(
                address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
            );

            // Make sure the project owner got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                mulDiv(
                    (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                        + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance),
                    _weight,
                    10 ** _NATIVE_DECIMALS
                ) * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT
            );
        }

        // Reclaim native tokens from the surplus by cashing out all of the `_beneficiary`'s tokens.
        vm.prank(_beneficiary);
        _terminal.cashOutTokensOf({
            holder: _beneficiary,
            projectId: _projectId,
            cashOutCount: _beneficiaryTokenBalance,
            tokenToReclaim: JBConstants.NATIVE_TOKEN,
            minTokensReclaimed: 0,
            beneficiary: payable(_beneficiary),
            metadata: new bytes(0)
        });

        // Check for a new beneficiary balance if one is expected.
        if (_nativePayAmount > _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit) {
            // Keep a reference to the total amount paid, including from fees.
            uint256 _totalPaid = _nativePayAmount + (_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance)
                + (_nativeCurrencyPayoutLimit - _projectOwnerNativeBalance);

            // Get the expected amount reclaimed.
            uint256 _nativeReclaimAmount = mulDiv(
                mulDiv(
                    _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance,
                    _beneficiaryTokenBalance,
                    mulDiv(_totalPaid, _weight, 10 ** _NATIVE_DECIMALS)
                ),
                _metadata.cashOutTaxRate
                    + mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                        mulDiv(_totalPaid, _weight, 10 ** _NATIVE_DECIMALS)
                    ),
                JBConstants.MAX_CASH_OUT_TAX_RATE
            );
            // Calculate the fee from the cash out.
            uint256 _feeAmount = _nativeReclaimAmount * _terminal.FEE() / JBConstants.MAX_FEE;

            // Make sure the beneficiary received tokens from the fee just paid.
            assertEq(
                _tokens.totalBalanceOf(_beneficiary, _projectId),
                mulDiv(_feeAmount, _weight, 10 ** _NATIVE_DECIMALS) * _metadata.reservedPercent
                    / JBConstants.MAX_RESERVED_PERCENT
            );

            // Make sure the beneficiary received the funds.
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance + _nativeReclaimAmount - _feeAmount);

            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                    - (_nativeReclaimAmount - _feeAmount)
            );
            assertEq(
                address(_terminal).balance,
                _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                    - (_nativeReclaimAmount - _feeAmount)
            );
        }
    }

    function testFuzzMultiCurrencyAllowance(
        uint224 _nativeCurrencySurplusAllowance,
        uint224 _nativeCurrencyPayoutLimit,
        uint256 _nativePayAmount,
        uint224 _usdCurrencySurplusAllowance,
        uint224 _usdCurrencyPayoutLimit,
        uint256 _usdcPayAmount
    )
        public
    {
        // Make sure the amount of native tokens to pay is bounded.
        _nativePayAmount = bound(_nativePayAmount, 0, 1_000_000 * 10 ** _NATIVE_DECIMALS);
        _usdcPayAmount = bound(_usdcPayAmount, 0, 1_000_000 * 10 ** _usdcToken.decimals());

        // Make sure the values don't overflow the registry.
        unchecked {
            vm.assume(
                _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencySurplusAllowance
                    && _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencyPayoutLimit
            );
            vm.assume(
                _usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit >= _usdCurrencySurplusAllowance
                    && _usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit >= _usdCurrencyPayoutLimit
            );
        }

        {
            // Package up the limits for the given terminal.
            JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);

            // Specify payout limits.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _payoutLimits[1] =
                JBCurrencyAmount({amount: _usdCurrencyPayoutLimit, currency: uint32(uint160(address(_usdcToken)))});

            // Specify surplus allowances.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](2);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _surplusAllowances[1] =
                JBCurrencyAmount({amount: _usdCurrencySurplusAllowance, currency: uint32(uint160(address(_usdcToken)))});

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });

            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

            JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
            JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
            _tokensToAccept[0] = JBAccountingContext({
                token: JBConstants.NATIVE_TOKEN,
                decimals: 18,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _tokensToAccept[1] = JBAccountingContext({
                token: address(_usdcToken),
                decimals: 6,
                currency: uint32(uint160(address(_usdcToken)))
            });
            _terminalConfigurations[0] =
                JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept});

            // Create a first project to collect fees.
            _controller.launchProjectFor({
                owner: _projectOwner, // Random.
                projectUri: "whatever",
                rulesetConfigurations: _rulesetConfigurations, // Use the same ruleset configurations.
                terminalConfigurations: _terminalConfigurations, // Set terminals to receive fees.
                memo: ""
            });

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Add a price feed to convert from native token to USD currencies.
        {
            vm.startPrank(_projectOwner);
            MockPriceFeed _priceFeedNativeUsd = new MockPriceFeed(_USD_PRICE_PER_NATIVE, _PRICE_FEED_DECIMALS);
            vm.label(address(_priceFeedNativeUsd), "Mock Price Feed Native-USDC");

            _controller.addPriceFeed({
                projectId: 1,
                pricingCurrency: uint32(uint160(address(_usdcToken))),
                unitCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                feed: _priceFeedNativeUsd
            });

            _controller.addPriceFeed({
                projectId: 2,
                pricingCurrency: uint32(uint160(address(_usdcToken))),
                unitCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                feed: _priceFeedNativeUsd
            });

            vm.stopPrank();
        }

        // Make a payment to the project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens from the native token payment.
        uint256 _beneficiaryTokenBalance = _unreservedPortion(mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS));
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);
        // Mint USDC to this contract.
        _usdcToken.mint(address(this), _usdcPayAmount);

        // Allow the terminal to spend the USDC.
        _usdcToken.approve(address(_terminal), _usdcPayAmount);

        // Make a payment to the project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal.pay({
            projectId: _projectId,
            amount: _usdcPayAmount,
            token: address(_usdcToken),
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );
        // Make sure the USDC is accounted for.
        assertEq(jbTerminalStore().balanceOf(address(_terminal), _projectId, address(_usdcToken)), _usdcPayAmount);
        assertEq(_usdcToken.balanceOf(address(_terminal)), _usdcPayAmount);

        {
            // Convert the USD amount to a native token amount, by way of the current weight used for issuance.
            uint256 _usdWeightedPayAmountConvertedToNative = mulDiv(
                _usdcPayAmount,
                _weight,
                mulDiv(_USD_PRICE_PER_NATIVE, 10 ** _usdcToken.decimals(), 10 ** _PRICE_FEED_DECIMALS)
            );

            // Make sure the beneficiary got the expected number of tokens from the USDC payment.
            _beneficiaryTokenBalance += _unreservedPortion(_usdWeightedPayAmountConvertedToNative);
            assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);
        }

        // Revert if there's no native token allowance.
        if (_nativeCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
        } else if (
            _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit + _toNative(_usdCurrencyPayoutLimit)
                > _nativePayAmount
        ) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencySurplusAllowance,
                    _nativeCurrencyPayoutLimit + _toNative(_usdCurrencyPayoutLimit) > _nativePayAmount
                        ? 0
                        : _nativePayAmount - _nativeCurrencyPayoutLimit - _toNative(_usdCurrencyPayoutLimit)
                )
            );
        }

        // Use the full native token surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Keep a reference to the beneficiary's native token balance.
        uint256 _beneficiaryNativeBalance;

        // Check the collected balance if one is expected.
        if (
            _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit + _toNative(_usdCurrencyPayoutLimit)
                <= _nativePayAmount
        ) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryNativeBalance = _nativeCurrencySurplusAllowance
                - mulDiv(_nativeCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _nativeCurrencySurplusAllowance
            );

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                _nativeCurrencySurplusAllowance - _beneficiaryNativeBalance
            );
            assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

            // Make sure the beneficiary got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                _unreservedPortion(
                    mulDiv(_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance, _weight, 10 ** _NATIVE_DECIMALS)
                )
            );
        } else {
            // Set the native token surplus allowance to 0 if it wasn't used.
            _nativeCurrencySurplusAllowance = 0;
        }

        // Revert if there's no native token allowance.
        if (_usdCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
            // revert if the USD surplus allowance resolved to native tokens is greater than 0, and there is sufficient
            // surplus to pull from including what was already pulled from.
        } else if (
            _toNative(_usdCurrencySurplusAllowance) > 0
                && _toNative(_usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit) + _nativeCurrencyPayoutLimit
                    + _nativeCurrencySurplusAllowance > _nativePayAmount
        ) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _toNative(_usdCurrencySurplusAllowance),
                    _toNative(_usdCurrencyPayoutLimit) + _nativeCurrencyPayoutLimit + _nativeCurrencySurplusAllowance
                        > _nativePayAmount
                        ? 0
                        : _nativePayAmount - _toNative(_usdCurrencyPayoutLimit) - _nativeCurrencyPayoutLimit
                            - _nativeCurrencySurplusAllowance
                )
            );
        }

        // Use the full native token surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _usdCurrencySurplusAllowance,
            currency: uint32(uint160(address(_usdcToken))),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Check the collected balance if one is expected.
        if (
            _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit
                + _toNative(_usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit) <= _nativePayAmount
        ) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryNativeBalance += _toNative(_usdCurrencySurplusAllowance)
                - mulDiv(_toNative(_usdCurrencySurplusAllowance), _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _nativeCurrencySurplusAllowance - _toNative(_usdCurrencySurplusAllowance)
            );

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                _nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance) - _beneficiaryNativeBalance
            );
            assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

            // Make sure the beneficiary got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                _unreservedPortion(
                    mulDiv(
                        _nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance)
                            - _beneficiaryNativeBalance,
                        _weight,
                        10 ** _NATIVE_DECIMALS
                    )
                )
            );
        } else {
            // Set the native token surplus allowance to 0 if it wasn't used.
            _usdCurrencySurplusAllowance = 0;
        }

        // Payout limits
        {
            // Revert if the payout limit is greater than the balance.
            if (_nativeCurrencyPayoutLimit > _nativePayAmount) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                        _nativeCurrencyPayoutLimit,
                        _nativePayAmount
                    )
                );
                // Revert if there's no payout limit.
            } else if (_nativeCurrencyPayoutLimit == 0) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0
                    )
                );
            }

            // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project
            // owner.
            _terminal.sendPayoutsOf({
                projectId: _projectId,
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                token: JBConstants.NATIVE_TOKEN,
                minTokensPaidOut: 0
            });

            uint256 _projectOwnerNativeBalance;

            // Check the received payout if one is expected.
            if (_nativeCurrencyPayoutLimit <= _nativePayAmount && _nativeCurrencyPayoutLimit != 0) {
                // Make sure the project owner received the funds that were paid out.
                _projectOwnerNativeBalance =
                    _nativeCurrencyPayoutLimit - _nativeCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;
                assertEq(_projectOwner.balance, _projectOwnerNativeBalance);
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                    _nativePayAmount - _nativeCurrencySurplusAllowance - _toNative(_usdCurrencySurplusAllowance)
                        - _nativeCurrencyPayoutLimit
                );

                // Make sure the fee was paid correctly.
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                    _nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance)
                        - _beneficiaryNativeBalance + _nativeCurrencyPayoutLimit - _projectOwnerNativeBalance
                );
                assertEq(
                    address(_terminal).balance,
                    _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                );

                uint256 _fullPortion = mulDiv(
                    _nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance)
                        - _beneficiaryNativeBalance + _nativeCurrencyPayoutLimit - _projectOwnerNativeBalance,
                    _weight,
                    10 ** _NATIVE_DECIMALS
                );

                // Make sure the project owner got the expected number of tokens.
                assertEq(_tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID), _unreservedPortion(_fullPortion));
            }

            // Revert if the payout limit is greater than the balance.
            if (
                _nativeCurrencyPayoutLimit <= _nativePayAmount
                    && _toNative(_usdCurrencyPayoutLimit) + _nativeCurrencyPayoutLimit > _nativePayAmount
            ) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                        _toNative(_usdCurrencyPayoutLimit),
                        _nativeCurrencyPayoutLimit > _nativePayAmount
                            ? _nativePayAmount
                            : _nativePayAmount - _nativeCurrencyPayoutLimit
                    )
                );
            } else if (
                _nativeCurrencyPayoutLimit > _nativePayAmount && _toNative(_usdCurrencyPayoutLimit) > _nativePayAmount
            ) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                        _toNative(_usdCurrencyPayoutLimit),
                        _nativePayAmount
                    )
                );
                // Revert if there's no payout limit.
            } else if (_usdCurrencyPayoutLimit == 0) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0
                    )
                );
            }

            // Pay out usdc tokens up to the payout limit. Since `splits[]` is empty, everything goes to project
            // owner.
            _terminal.sendPayoutsOf({
                projectId: _projectId,
                amount: _usdCurrencyPayoutLimit,
                currency: uint32(uint160(address(_usdcToken))),
                token: JBConstants.NATIVE_TOKEN,
                minTokensPaidOut: 0
            });

            // Check the received payout if one is expected.
            if (
                _toNative(_usdCurrencyPayoutLimit) + _nativeCurrencyPayoutLimit <= _nativePayAmount
                    && _usdCurrencyPayoutLimit > 0
            ) {
                // Make sure the project owner received the funds that were paid out.
                _projectOwnerNativeBalance += _toNative(_usdCurrencyPayoutLimit)
                    - _toNative(_usdCurrencyPayoutLimit) * _terminal.FEE() / JBConstants.MAX_FEE;
                assertEq(_projectOwner.balance, _projectOwnerNativeBalance);
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                    _nativePayAmount - _nativeCurrencySurplusAllowance - _toNative(_usdCurrencySurplusAllowance)
                        - _nativeCurrencyPayoutLimit - _toNative(_usdCurrencyPayoutLimit)
                );

                // Make sure the fee was paid correctly.
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                    (
                        _nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance)
                            - _beneficiaryNativeBalance
                    ) + (_nativeCurrencyPayoutLimit + _toNative(_usdCurrencyPayoutLimit) - _projectOwnerNativeBalance)
                );
                assertEq(
                    address(_terminal).balance,
                    _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                );
            }
        }

        // Keep a reference to the remaining native token surplus.
        uint256 _nativeSurplus = _nativeCurrencyPayoutLimit + _toNative(_usdCurrencyPayoutLimit)
            + _nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance) >= _nativePayAmount
            ? 0
            : _nativePayAmount - _nativeCurrencyPayoutLimit - _toNative(_usdCurrencyPayoutLimit)
                - _nativeCurrencySurplusAllowance - _toNative(_usdCurrencySurplusAllowance);

        // Keep a reference to the remaining native token balance.
        uint256 _nativeBalance =
            _nativePayAmount - _nativeCurrencySurplusAllowance - _toNative(_usdCurrencySurplusAllowance);
        if (_nativeCurrencyPayoutLimit <= _nativePayAmount) {
            _nativeBalance -= _nativeCurrencyPayoutLimit;
            if (_toNative(_usdCurrencyPayoutLimit) + _nativeCurrencyPayoutLimit <= _nativePayAmount) {
                _nativeBalance -= _toNative(_usdCurrencyPayoutLimit);
            }
        } else if (_toNative(_usdCurrencyPayoutLimit) <= _nativePayAmount) {
            _nativeBalance -= _toNative(_usdCurrencyPayoutLimit);
        }

        // Make sure it's correct.
        assertEq(jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativeBalance);

        // Make sure the USDC surplus is correct.
        assertEq(jbTerminalStore().balanceOf(address(_terminal), _projectId, address(_usdcToken)), _usdcPayAmount);

        // Make sure the total token supply is correct.
        assertEq(
            _controller.totalTokenSupplyWithReservedTokensOf(_projectId),
            mulDiv(
                _beneficiaryTokenBalance,
                JBConstants.MAX_RESERVED_PERCENT,
                JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
            )
        );

        // Keep a reference to the amount of native tokens being reclaimed.
        uint256 _nativeReclaimAmount;

        vm.startPrank(_beneficiary);

        // If there's surplus.
        if (_toNative(mulDiv(_usdcPayAmount, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals())) + _nativeSurplus > 0)
        {
            // Get the expected amount reclaimed.
            _nativeReclaimAmount = mulDiv(
                mulDiv(
                    _toNative(mulDiv(_usdcPayAmount, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals()))
                        + _nativeSurplus,
                    _beneficiaryTokenBalance,
                    mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_RESERVED_PERCENT,
                        JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
                    )
                ),
                _metadata.cashOutTaxRate
                    + mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                        mulDiv(
                            _beneficiaryTokenBalance,
                            JBConstants.MAX_RESERVED_PERCENT,
                            JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
                        )
                    ),
                JBConstants.MAX_CASH_OUT_TAX_RATE
            );

            // If there is more to reclaim than there are native tokens in the tank.
            if (_nativeReclaimAmount > _nativeSurplus) {
                // Keep a reference to the amount to cash out for native tokens, a proportion of available surplus in
                // native tokens.
                uint256 _tokenCountToCashOutForNative = mulDiv(
                    _beneficiaryTokenBalance,
                    _nativeSurplus,
                    _nativeSurplus
                        + _toNative(mulDiv(_usdcPayAmount, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals()))
                );
                uint256 _tokenSupply = mulDiv(
                    _beneficiaryTokenBalance,
                    JBConstants.MAX_RESERVED_PERCENT,
                    JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
                );
                // Cash out native tokens from the surplus using only the `_beneficiary`'s tokens needed to clear the
                // native token balance.
                _terminal.cashOutTokensOf({
                    holder: _beneficiary,
                    projectId: _projectId,
                    cashOutCount: _tokenCountToCashOutForNative,
                    tokenToReclaim: JBConstants.NATIVE_TOKEN,
                    minTokensReclaimed: 0,
                    beneficiary: payable(_beneficiary),
                    metadata: new bytes(0)
                });

                // Cash out USDC from the surplus using only the `_beneficiary`'s tokens needed to clear the USDC
                // balance.
                _terminal.cashOutTokensOf({
                    holder: _beneficiary,
                    projectId: _projectId,
                    cashOutCount: _beneficiaryTokenBalance - _tokenCountToCashOutForNative,
                    tokenToReclaim: address(_usdcToken),
                    minTokensReclaimed: 0,
                    beneficiary: payable(_beneficiary),
                    metadata: new bytes(0)
                });

                _nativeReclaimAmount = mulDiv(
                    mulDiv(
                        _toNative(mulDiv(_usdcPayAmount, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals()))
                            + _nativeSurplus,
                        _tokenCountToCashOutForNative,
                        _tokenSupply
                    ),
                    _metadata.cashOutTaxRate
                        + mulDiv(
                            _tokenCountToCashOutForNative,
                            JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                            _tokenSupply
                        ),
                    JBConstants.MAX_CASH_OUT_TAX_RATE
                );

                uint256 _usdcReclaimAmount = mulDiv(
                    mulDiv(
                        _usdcPayAmount
                            + _toUsd(
                                mulDiv(
                                    _nativeSurplus - _nativeReclaimAmount,
                                    10 ** _usdcToken.decimals(),
                                    10 ** _NATIVE_DECIMALS
                                )
                            ),
                        _beneficiaryTokenBalance - _tokenCountToCashOutForNative,
                        _tokenSupply - _tokenCountToCashOutForNative
                    ),
                    _metadata.cashOutTaxRate
                        + mulDiv(
                            _beneficiaryTokenBalance - _tokenCountToCashOutForNative,
                            JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                            _tokenSupply - _tokenCountToCashOutForNative
                        ),
                    JBConstants.MAX_CASH_OUT_TAX_RATE
                );

                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _projectId, address(_usdcToken)),
                    _usdcPayAmount - _usdcReclaimAmount
                );

                uint256 _usdcFeeAmount = _usdcReclaimAmount * _terminal.FEE() / JBConstants.MAX_FEE;
                assertEq(_usdcToken.balanceOf(_beneficiary), _usdcReclaimAmount - _usdcFeeAmount);

                // Make sure the fee was paid correctly.
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, address(_usdcToken)),
                    _usdcFeeAmount
                );
                assertEq(_usdcToken.balanceOf(address(_terminal)), _usdcPayAmount - _usdcReclaimAmount + _usdcFeeAmount);
            } else {
                // Reclaim native tokens from the surplus by cashing out all of the `_beneficiary`'s tokens.
                _terminal.cashOutTokensOf({
                    holder: _beneficiary,
                    projectId: _projectId,
                    cashOutCount: _beneficiaryTokenBalance,
                    tokenToReclaim: JBConstants.NATIVE_TOKEN,
                    minTokensReclaimed: 0,
                    beneficiary: payable(_beneficiary),
                    metadata: new bytes(0)
                });
            }
            // Burn the tokens.
        } else {
            _terminal.cashOutTokensOf({
                holder: _beneficiary,
                projectId: _projectId,
                cashOutCount: _beneficiaryTokenBalance,
                tokenToReclaim: address(_usdcToken),
                minTokensReclaimed: 0,
                beneficiary: payable(_beneficiary),
                metadata: new bytes(0)
            });
        }
        vm.stopPrank();

        // Make sure the balance is adjusted by the reclaim amount.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _nativeBalance - _nativeReclaimAmount
        );
    }

    // Project 2 accepts native tokens into `_terminal` and USDC into `_terminal2`.
    // Project 1 accepts USDC and native token fees into `_terminal`.
    function testFuzzMultiTerminalAllowance(
        uint224 _nativeCurrencySurplusAllowance,
        uint224 _nativeCurrencyPayoutLimit,
        uint256 _nativePayAmount,
        uint224 _usdCurrencySurplusAllowance,
        uint224 _usdCurrencyPayoutLimit,
        uint256 _usdcPayAmount
    )
        public
    {
        // Make sure the amount of native tokens to pay is bounded.
        _nativePayAmount = bound(_nativePayAmount, 0, 1_000_000 * 10 ** _NATIVE_DECIMALS);
        _usdcPayAmount = bound(_usdcPayAmount, 0, 1_000_000 * 10 ** _usdcToken.decimals());
        _usdCurrencyPayoutLimit = uint224(
            bound(_usdCurrencyPayoutLimit, 0, type(uint224).max / 10 ** (_NATIVE_DECIMALS - _usdcToken.decimals()))
        );

        // Make sure the values don't overflow the registry.
        unchecked {
            vm.assume(
                _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencySurplusAllowance
                    && _nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit >= _nativeCurrencyPayoutLimit
            );
            vm.assume(
                _usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit >= _usdCurrencySurplusAllowance
                    && _usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit >= _usdCurrencyPayoutLimit
            );
        }

        {
            // Package up the limits for the given terminal.
            JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](2);

            // Specify payout limits.
            JBCurrencyAmount[] memory _payoutLimits1 = new JBCurrencyAmount[](1);
            JBCurrencyAmount[] memory _payoutLimits2 = new JBCurrencyAmount[](1);
            _payoutLimits1[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _payoutLimits2[0] =
                JBCurrencyAmount({amount: _usdCurrencyPayoutLimit, currency: uint32(uint160(address(_usdcToken)))});

            // Specify surplus allowances.
            JBCurrencyAmount[] memory _surplusAllowances1 = new JBCurrencyAmount[](1);
            JBCurrencyAmount[] memory _surplusAllowances2 = new JBCurrencyAmount[](1);
            _surplusAllowances1[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _surplusAllowances2[0] =
                JBCurrencyAmount({amount: _usdCurrencySurplusAllowance, currency: uint32(uint160(address(_usdcToken)))});

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits1,
                surplusAllowances: _surplusAllowances1
            });

            _fundAccessLimitGroup[1] = JBFundAccessLimitGroup({
                terminal: address(_terminal2),
                token: address(_usdcToken),
                payoutLimits: _payoutLimits2,
                surplusAllowances: _surplusAllowances2
            });

            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

            JBTerminalConfig[] memory _terminalConfigurations1 = new JBTerminalConfig[](1);
            JBTerminalConfig[] memory _terminalConfigurations2 = new JBTerminalConfig[](2);
            JBAccountingContext[] memory _tokensToAccept1 = new JBAccountingContext[](2);
            _tokensToAccept1[0] = JBAccountingContext({
                token: JBConstants.NATIVE_TOKEN,
                decimals: 18,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });
            _tokensToAccept1[1] = JBAccountingContext({
                token: address(_usdcToken),
                decimals: 6,
                currency: uint32(uint160(address(_usdcToken)))
            });

            JBAccountingContext[] memory _tokensToAccept2 = new JBAccountingContext[](1);
            _tokensToAccept2[0] = JBAccountingContext({
                token: JBConstants.NATIVE_TOKEN,
                decimals: 18,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            JBAccountingContext[] memory _tokensToAccept3 = new JBAccountingContext[](1);
            _tokensToAccept3[0] = JBAccountingContext({
                token: address(_usdcToken),
                decimals: 6,
                currency: uint32(uint160(address(_usdcToken)))
            });

            // Fee takes USDC and native token in same terminal.
            _terminalConfigurations1[0] =
                JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept1});
            _terminalConfigurations2[0] =
                JBTerminalConfig({terminal: _terminal, accountingContextsToAccept: _tokensToAccept2});
            _terminalConfigurations2[1] =
                JBTerminalConfig({terminal: _terminal2, accountingContextsToAccept: _tokensToAccept3});

            // Create a first project to collect fees.
            _controller.launchProjectFor({
                owner: _projectOwner, // Random.
                projectUri: "whatever",
                rulesetConfigurations: _rulesetConfigurations, // Use the same ruleset configurations.
                terminalConfigurations: _terminalConfigurations1, // Set terminals to receive fees.
                memo: ""
            });

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: _projectOwner,
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations2,
                memo: ""
            });
        }

        // Add a price feed to convert from native token to USD currencies.
        {
            vm.startPrank(_projectOwner);
            MockPriceFeed _priceFeedNativeUsd = new MockPriceFeed(_USD_PRICE_PER_NATIVE, _PRICE_FEED_DECIMALS);
            vm.label(address(_priceFeedNativeUsd), "Mock Price Feed Native-USDC");

            _controller.addPriceFeed({
                projectId: 1,
                pricingCurrency: uint32(uint160(address(_usdcToken))),
                unitCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                feed: _priceFeedNativeUsd
            });

            _controller.addPriceFeed({
                projectId: 2,
                pricingCurrency: uint32(uint160(address(_usdcToken))),
                unitCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                feed: _priceFeedNativeUsd
            });

            vm.stopPrank();
        }

        // Make a payment to the project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens from the native token payment.
        uint256 _beneficiaryTokenBalance = _unreservedPortion(mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS));
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);
        // Mint USDC to this contract.
        _usdcToken.mint(address(this), _usdcPayAmount);

        // Allow the terminal to spend the USDC.
        _usdcToken.approve(address(_terminal2), _usdcPayAmount);

        // Make a payment to the project to give it a starting balance. Send the tokens to the `_beneficiary`.
        _terminal2.pay({
            projectId: _projectId,
            amount: _usdcPayAmount,
            token: address(_usdcToken),
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );
        // Make sure the USDC is accounted for.
        assertEq(jbTerminalStore().balanceOf(address(_terminal2), _projectId, address(_usdcToken)), _usdcPayAmount);
        assertEq(_usdcToken.balanceOf(address(_terminal2)), _usdcPayAmount);

        {
            // Convert the USD amount to a native token amount, by way of the current weight used for issuance.
            uint256 _usdWeightedPayAmountConvertedToNative = mulDiv(
                _usdcPayAmount,
                _weight,
                mulDiv(_USD_PRICE_PER_NATIVE, 10 ** _usdcToken.decimals(), 10 ** _PRICE_FEED_DECIMALS)
            );

            // Make sure the beneficiary got the expected number of tokens from the USDC payment.
            _beneficiaryTokenBalance += _unreservedPortion(_usdWeightedPayAmountConvertedToNative);
            assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);
        }

        // Revert if there's no native token allowance.
        if (_nativeCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
        } else if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit > _nativePayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _nativeCurrencySurplusAllowance,
                    _nativeCurrencyPayoutLimit > _nativePayAmount ? 0 : _nativePayAmount - _nativeCurrencyPayoutLimit
                )
            );
        }

        // Use the full native token surplus allowance.
        vm.prank(_projectOwner);
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Keep a reference to the beneficiary's native token balance.
        uint256 _beneficiaryNativeBalance;

        // Check the collected balance if one is expected.
        if (_nativeCurrencySurplusAllowance + _nativeCurrencyPayoutLimit <= _nativePayAmount) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryNativeBalance = _nativeCurrencySurplusAllowance
                - mulDiv(_nativeCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_beneficiary.balance, _beneficiaryNativeBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                _nativePayAmount - _nativeCurrencySurplusAllowance
            );

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                _nativeCurrencySurplusAllowance - _beneficiaryNativeBalance
            );
            assertEq(address(_terminal).balance, _nativePayAmount - _beneficiaryNativeBalance);

            // Make sure the beneficiary got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                _unreservedPortion(
                    mulDiv(_nativeCurrencySurplusAllowance - _beneficiaryNativeBalance, _weight, 10 ** _NATIVE_DECIMALS)
                )
            );
        } else {
            // Set the native token surplus allowance to 0 if it wasn't used.
            _nativeCurrencySurplusAllowance = 0;
        }

        // Revert if there's no native token allowance.
        if (_usdCurrencySurplusAllowance == 0) {
            vm.expectRevert(
                abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InadequateControllerAllowance.selector, 0, 0)
            );
            // Revert if the USD surplus allowance resolved to native tokens is greater than 0, and there is sufficient
            // surplus to pull from including what was already pulled from.
        } else if (_usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit > _usdcPayAmount) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                    _usdCurrencySurplusAllowance,
                    _usdCurrencyPayoutLimit > _usdcPayAmount ? 0 : _usdcPayAmount - _usdCurrencyPayoutLimit
                )
            );
        }

        // Use the full native token surplus allowance.
        vm.prank(_projectOwner);
        _terminal2.useAllowanceOf({
            projectId: _projectId,
            amount: _usdCurrencySurplusAllowance,
            currency: uint32(uint160(address(_usdcToken))),
            token: address(_usdcToken),
            minTokensPaidOut: 0,
            beneficiary: payable(_beneficiary),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });

        // Keep a reference to the beneficiary's USDC balance.
        uint256 _beneficiaryUsdcBalance;

        // Check the collected balance if one is expected.
        if (_usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit <= _usdcPayAmount) {
            // Make sure the beneficiary received the funds and that they are no longer in the terminal.
            _beneficiaryUsdcBalance += _usdCurrencySurplusAllowance
                - mulDiv(_usdCurrencySurplusAllowance, _terminal.FEE(), JBConstants.MAX_FEE);
            assertEq(_usdcToken.balanceOf(_beneficiary), _beneficiaryUsdcBalance);
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal2), _projectId, address(_usdcToken)),
                _usdcPayAmount - _usdCurrencySurplusAllowance
            );

            // Make sure the fee was paid correctly.
            assertEq(
                jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, address(_usdcToken)),
                _usdCurrencySurplusAllowance - _beneficiaryUsdcBalance
            );
            assertEq(_usdcToken.balanceOf(address(_terminal2)), _usdcPayAmount - _usdCurrencySurplusAllowance);
            assertEq(_usdcToken.balanceOf(address(_terminal)), _usdCurrencySurplusAllowance - _beneficiaryUsdcBalance);

            // Make sure the beneficiary got the expected number of tokens.
            assertEq(
                _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID),
                _unreservedPortion(
                    mulDiv(
                        _nativeCurrencySurplusAllowance
                            + _toNative(
                                mulDiv(_usdCurrencySurplusAllowance, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals())
                            ) - _beneficiaryNativeBalance
                            - _toNative(
                                mulDiv(_beneficiaryUsdcBalance, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals())
                            ),
                        _weight,
                        10 ** _NATIVE_DECIMALS
                    )
                )
            );
        } else {
            // Set the native token surplus allowance to 0 if it wasn't used.
            _usdCurrencySurplusAllowance = 0;
        }

        // Payout limits
        {
            // Revert if the payout limit is greater than the balance.
            if (_nativeCurrencyPayoutLimit > _nativePayAmount) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                        _nativeCurrencyPayoutLimit,
                        _nativePayAmount
                    )
                );
                // Revert if there's no payout limit.
            } else if (_nativeCurrencyPayoutLimit == 0) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0
                    )
                );
            }

            // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project
            // owner.
            _terminal.sendPayoutsOf({
                projectId: _projectId,
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                token: JBConstants.NATIVE_TOKEN,
                minTokensPaidOut: 0
            });

            uint256 _projectOwnerNativeBalance;

            // Check the received payout if one is expected.
            if (_nativeCurrencyPayoutLimit <= _nativePayAmount && _nativeCurrencyPayoutLimit != 0) {
                // Make sure the project owner received the funds that were paid out.
                _projectOwnerNativeBalance =
                    _nativeCurrencyPayoutLimit - _nativeCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;
                assertEq(_projectOwner.balance, _projectOwnerNativeBalance);
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
                    _nativePayAmount - _nativeCurrencySurplusAllowance - _nativeCurrencyPayoutLimit
                );

                // Make sure the fee was paid correctly.
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, JBConstants.NATIVE_TOKEN),
                    _nativeCurrencySurplusAllowance - _beneficiaryNativeBalance + _nativeCurrencyPayoutLimit
                        - _projectOwnerNativeBalance
                );
                assertEq(
                    address(_terminal).balance,
                    _nativePayAmount - _beneficiaryNativeBalance - _projectOwnerNativeBalance
                );

                // // // Make sure the project owner got the expected number of tokens.
                // assertEq(
                // _unreservedPortion(mulDiv(_nativeCurrencySurplusAllowance + _toNative(_usdCurrencySurplusAllowance) -
                // _beneficiaryNativeBalance + _nativeCurrencyPayoutLimit - _projectOwnerNativeBalance, _weight, 10
                // ** _NATIVE_DECIMALS)), _tokens.totalBalanceOf(_projectOwner, _FEE_PROJECT_ID));
            }

            // Revert if the payout limit is greater than the balance.
            if (_usdCurrencyPayoutLimit > _usdcPayAmount) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector,
                        _usdCurrencyPayoutLimit,
                        _usdcPayAmount
                    )
                );
                // Revert if there's no payout limit.
            } else if (_usdCurrencyPayoutLimit == 0) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 0, 0
                    )
                );
            }

            // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project
            // owner.
            _terminal2.sendPayoutsOf({
                projectId: _projectId,
                amount: _usdCurrencyPayoutLimit,
                currency: uint32(uint160(address(_usdcToken))),
                token: address(_usdcToken),
                minTokensPaidOut: 0
            });

            uint256 _projectOwnerUsdcBalance;

            // Check the received payout if one is expected.
            if (_usdCurrencyPayoutLimit <= _usdcPayAmount && _usdCurrencyPayoutLimit != 0) {
                // Make sure the project owner received the funds that were paid out.
                _projectOwnerUsdcBalance =
                    _usdCurrencyPayoutLimit - _usdCurrencyPayoutLimit * _terminal.FEE() / JBConstants.MAX_FEE;
                assertEq(_usdcToken.balanceOf(_projectOwner), _projectOwnerUsdcBalance);
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal2), _projectId, address(_usdcToken)),
                    _usdcPayAmount - _usdCurrencySurplusAllowance - _usdCurrencyPayoutLimit
                );

                // Make sure the fee was paid correctly.
                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal), _FEE_PROJECT_ID, address(_usdcToken)),
                    _usdCurrencySurplusAllowance - _beneficiaryUsdcBalance + _usdCurrencyPayoutLimit
                        - _projectOwnerUsdcBalance
                );
                assertEq(
                    _usdcToken.balanceOf(address(_terminal2)),
                    _usdcPayAmount - _usdCurrencySurplusAllowance - _usdCurrencyPayoutLimit
                );
                assertEq(
                    _usdcToken.balanceOf(address(_terminal)),
                    _usdCurrencySurplusAllowance + _usdCurrencyPayoutLimit - _beneficiaryUsdcBalance
                        - _projectOwnerUsdcBalance
                );
            }
        }

        // Keep a reference to the remaining native token surplus.
        uint256 _nativeSurplus = _nativeCurrencyPayoutLimit + _nativeCurrencySurplusAllowance >= _nativePayAmount
            ? 0
            : _nativePayAmount - _nativeCurrencyPayoutLimit - _nativeCurrencySurplusAllowance;

        uint256 _usdcSurplus = _usdCurrencyPayoutLimit + _usdCurrencySurplusAllowance >= _usdcPayAmount
            ? 0
            : _usdcPayAmount - _usdCurrencyPayoutLimit - _usdCurrencySurplusAllowance;

        // Keep a reference to the remaining native token balance.
        uint256 _usdcBalanceInTerminal = _usdcPayAmount - _usdCurrencySurplusAllowance;

        if (_usdCurrencyPayoutLimit <= _usdcPayAmount) {
            _usdcBalanceInTerminal -= _usdCurrencyPayoutLimit;
        }

        assertEq(_usdcToken.balanceOf(address(_terminal2)), _usdcBalanceInTerminal);

        // Make sure the total token supply is correct.
        assertEq(
            jbController().totalTokenSupplyWithReservedTokensOf(_projectId),
            mulDiv(
                _beneficiaryTokenBalance,
                JBConstants.MAX_RESERVED_PERCENT,
                JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
            )
        );

        // Keep a reference to the amount of native tokens being reclaimed.
        uint256 _nativeReclaimAmount;

        vm.startPrank(_beneficiary);

        // If there's native token surplus.
        if (_nativeSurplus + _toNative(mulDiv(_usdcSurplus, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals())) > 0) {
            // Get the expected amount reclaimed.
            _nativeReclaimAmount = mulDiv(
                mulDiv(
                    _nativeSurplus
                        + _toNative(mulDiv(_usdcSurplus, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals())),
                    _beneficiaryTokenBalance,
                    mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_RESERVED_PERCENT,
                        JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
                    )
                ),
                _metadata.cashOutTaxRate
                    + mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                        mulDiv(
                            _beneficiaryTokenBalance,
                            JBConstants.MAX_RESERVED_PERCENT,
                            JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
                        )
                    ),
                JBConstants.MAX_CASH_OUT_TAX_RATE
            );

            // If there is more to reclaim than there are native tokens in the tank.
            if (_nativeReclaimAmount > _nativeSurplus) {
                uint256 _usdcReclaimAmount;
                {
                    // Keep a reference to the amount of project tokens to cash out for native tokens, a proportion of
                    // available native token surplus.
                    uint256 _tokenCountToCashOutForNative = mulDiv(
                        _beneficiaryTokenBalance,
                        _nativeSurplus,
                        _nativeSurplus
                            + _toNative(mulDiv(_usdcSurplus, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals()))
                    );
                    uint256 _tokenSupply = mulDiv(
                        _beneficiaryTokenBalance,
                        JBConstants.MAX_RESERVED_PERCENT,
                        JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent
                    );
                    // Cash out native tokens from the surplus using only the `_beneficiary`'s tokens needed to clear
                    // the
                    // native token balance.
                    _terminal.cashOutTokensOf({
                        holder: _beneficiary,
                        projectId: _projectId,
                        cashOutCount: _tokenCountToCashOutForNative,
                        tokenToReclaim: JBConstants.NATIVE_TOKEN,
                        minTokensReclaimed: 0,
                        beneficiary: payable(_beneficiary),
                        metadata: new bytes(0)
                    });

                    // Cash out USDC from the surplus using only the `_beneficiary`'s tokens needed to clear the USDC
                    // balance.
                    _terminal2.cashOutTokensOf({
                        holder: _beneficiary,
                        projectId: _projectId,
                        cashOutCount: _beneficiaryTokenBalance - _tokenCountToCashOutForNative,
                        tokenToReclaim: address(_usdcToken),
                        minTokensReclaimed: 0,
                        beneficiary: payable(_beneficiary),
                        metadata: new bytes(0)
                    });

                    _nativeReclaimAmount = mulDiv(
                        mulDiv(
                            _nativeSurplus
                                + _toNative(mulDiv(_usdcSurplus, 10 ** _NATIVE_DECIMALS, 10 ** _usdcToken.decimals())),
                            _tokenCountToCashOutForNative,
                            _tokenSupply
                        ),
                        _metadata.cashOutTaxRate
                            + mulDiv(
                                _tokenCountToCashOutForNative,
                                JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                                _tokenSupply
                            ),
                        JBConstants.MAX_CASH_OUT_TAX_RATE
                    );
                    _usdcReclaimAmount = mulDiv(
                        mulDiv(
                            _usdcSurplus
                                + _toUsd(
                                    mulDiv(
                                        _nativeSurplus - _nativeReclaimAmount,
                                        10 ** _usdcToken.decimals(),
                                        10 ** _NATIVE_DECIMALS
                                    )
                                ),
                            _beneficiaryTokenBalance - _tokenCountToCashOutForNative,
                            _tokenSupply - _tokenCountToCashOutForNative
                        ),
                        _metadata.cashOutTaxRate
                            + mulDiv(
                                _beneficiaryTokenBalance - _tokenCountToCashOutForNative,
                                JBConstants.MAX_CASH_OUT_TAX_RATE - _metadata.cashOutTaxRate,
                                _tokenSupply - _tokenCountToCashOutForNative
                            ),
                        JBConstants.MAX_CASH_OUT_TAX_RATE
                    );
                }

                assertEq(
                    jbTerminalStore().balanceOf(address(_terminal2), _projectId, address(_usdcToken)),
                    _usdcSurplus - _usdcReclaimAmount
                );

                uint256 _usdcFeeAmount = _usdcReclaimAmount * _terminal.FEE() / JBConstants.MAX_FEE;

                _beneficiaryUsdcBalance += _usdcReclaimAmount - _usdcFeeAmount;
                assertEq(_usdcToken.balanceOf(_beneficiary), _beneficiaryUsdcBalance);

                assertEq(_usdcToken.balanceOf(address(_terminal2)), _usdcBalanceInTerminal - _usdcReclaimAmount);

                // Only the fees left.
                assertEq(
                    _usdcToken.balanceOf(address(_terminal)),
                    _usdcPayAmount - _usdcToken.balanceOf(address(_terminal2)) - _usdcToken.balanceOf(_beneficiary)
                        - _usdcToken.balanceOf(_projectOwner)
                );
            } else {
                // Reclaim native tokens from the surplus by cashing out all of the `_beneficiary`'s tokens.
                _terminal.cashOutTokensOf({
                    holder: _beneficiary,
                    projectId: _projectId,
                    cashOutCount: _beneficiaryTokenBalance,
                    tokenToReclaim: JBConstants.NATIVE_TOKEN,
                    minTokensReclaimed: 0,
                    beneficiary: payable(_beneficiary),
                    metadata: new bytes(0)
                });
            }
            // Burn the tokens.
        } else {
            _terminal2.cashOutTokensOf({
                holder: _beneficiary,
                projectId: _projectId,
                cashOutCount: _beneficiaryTokenBalance,
                tokenToReclaim: address(_usdcToken),
                minTokensReclaimed: 0,
                beneficiary: payable(_beneficiary),
                metadata: new bytes(0)
            });
        }
        vm.stopPrank();

        // Keep a reference to the remaining native token balance.
        uint256 _projectNativeBalance = _nativePayAmount - _nativeCurrencySurplusAllowance;
        if (_nativeCurrencyPayoutLimit <= _nativePayAmount) {
            _projectNativeBalance -= _nativeCurrencyPayoutLimit;
        }

        // Make sure the balance is adjusted by the reclaim amount.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN),
            _projectNativeBalance - _nativeReclaimAmount
        );
    }

    // Tests that recent changes to JBTerminalStore are safe wrt reetrency via useAllowanceOf.
    function testNativeAllowanceReentry() public {
        // Hardcode values to use.
        uint224 _nativeCurrencyPayoutLimit = uint224(10 * 10 ** _NATIVE_DECIMALS);
        uint224 _nativeCurrencySurplusAllowance = uint224(5 * 10 ** _NATIVE_DECIMALS);

        MaliciousAllowanceBeneficiary maliciousOwner = new MaliciousAllowanceBeneficiary();

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        {
            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

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
                owner: address(420), // Random.
                projectUri: "whatever",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations, // Set terminals to receive fees.
                memo: ""
            });

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: address(maliciousOwner),
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Get a reference to the amount being paid.
        // The amount being paid is the payout limit plus two times the surplus allowance.
        uint256 _nativePayAmount = _nativeCurrencyPayoutLimit + (5 * _nativeCurrencySurplusAllowance);

        // Pay the project such that the `_beneficiary` receives project tokens.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens.
        uint256 _beneficiaryTokenBalance = mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );

        // Attempt to use more than surplus allowance via malicious beneficiary contract.
        // This will fail via the mock contract itself, with an expected revert therein corresponding to the amounts.
        // See {MockMaliciousAllowanceBeneficiary}
        vm.prank(address(maliciousOwner));
        _terminal.useAllowanceOf({
            projectId: _projectId,
            amount: _nativeCurrencySurplusAllowance,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0,
            beneficiary: payable(address(maliciousOwner)),
            feeBeneficiary: payable(_projectOwner),
            memo: "MEMO"
        });
    }

    // Tests that recent changes to JBTerminalStore are safe wrt reetrency via sendPayoutsOf.
    function testNativePayoutReentry() public {
        // Hardcode values to use.
        uint224 _nativeCurrencyPayoutLimit = uint224(10 * 10 ** _NATIVE_DECIMALS);
        uint224 _nativeCurrencySurplusAllowance = uint224(5 * 10 ** _NATIVE_DECIMALS);

        MaliciousPayoutBeneficiary maliciousPayoutCaller = new MaliciousPayoutBeneficiary();

        // Package up the limits for the given terminal.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] = JBCurrencyAmount({
                amount: _nativeCurrencyPayoutLimit,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] = JBCurrencyAmount({
                amount: _nativeCurrencySurplusAllowance,
                currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
            });

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        {
            // Package up the ruleset configuration.
            JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
            _rulesetConfigurations[0].mustStartAtOrAfter = 0;
            _rulesetConfigurations[0].duration = 0;
            _rulesetConfigurations[0].weight = _weight;
            _rulesetConfigurations[0].weightCutPercent = 0;
            _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
            _rulesetConfigurations[0].metadata = _metadata;
            _rulesetConfigurations[0].splitGroups = new JBSplitGroup[](0);
            _rulesetConfigurations[0].fundAccessLimitGroups = _fundAccessLimitGroup;

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
                owner: address(420), // Random.
                projectUri: "whatever",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations, // Set terminals to receive fees.
                memo: ""
            });

            // Create the project to test.
            _projectId = _controller.launchProjectFor({
                owner: address(maliciousPayoutCaller),
                projectUri: "myIPFSHash",
                rulesetConfigurations: _rulesetConfigurations,
                terminalConfigurations: _terminalConfigurations,
                memo: ""
            });
        }

        // Get a reference to the amount being paid.
        // The amount being paid is the payout limit plus five times the surplus allowance.
        uint256 _nativePayAmount = _nativeCurrencyPayoutLimit + (5 * _nativeCurrencySurplusAllowance);

        // Pay the project such that the `_beneficiary` receives project tokens.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: new bytes(0)
        });

        // Make sure the beneficiary got the expected number of tokens.
        uint256 _beneficiaryTokenBalance = mulDiv(_nativePayAmount, _weight, 10 ** _NATIVE_DECIMALS)
            * _metadata.reservedPercent / JBConstants.MAX_RESERVED_PERCENT;
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _beneficiaryTokenBalance);

        // Make sure the terminal holds the full native token balance.
        assertEq(
            jbTerminalStore().balanceOf(address(_terminal), _projectId, JBConstants.NATIVE_TOKEN), _nativePayAmount
        );

        // Pay out native tokens up to the payout limit. Since `splits[]` is empty, everything goes to project owner.
        // Project owner is our malicious contract that attempts to hijack control flow and execute subsequent calls
        // successfully.
        // This will fail via the mock contract itself, with an expected revert corresponding to the amounts.
        // See {MockMaliciousPayoutBeneficiary}
        _terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativeCurrencyPayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN,
            minTokensPaidOut: 0
        });
    }

    function _toNative(uint256 _usdVal) internal pure returns (uint256) {
        return mulDiv(_usdVal, 10 ** _PRICE_FEED_DECIMALS, _USD_PRICE_PER_NATIVE);
    }

    function _toUsd(uint256 _nativeVal) internal pure returns (uint256) {
        return mulDiv(_nativeVal, _USD_PRICE_PER_NATIVE, 10 ** _PRICE_FEED_DECIMALS);
    }

    function _unreservedPortion(uint256 _fullPortion) internal view returns (uint256) {
        return mulDiv(
            _fullPortion, JBConstants.MAX_RESERVED_PERCENT - _metadata.reservedPercent, JBConstants.MAX_RESERVED_PERCENT
        );
    }
}
