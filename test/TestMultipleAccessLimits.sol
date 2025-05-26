// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";
import {MockPriceFeed} from "./mock/MockPriceFeed.sol";

contract TestMultipleAccessLimits_Local is TestBaseWorkflow {
    uint32 private _nativeCurrency;
    IJBController private _controller;
    IJBMultiTerminal private __terminal;
    IJBPrices private _prices;
    JBTokens private _tokens;
    uint112 private _weight;
    JBRulesetMetadata _metadata;
    JBSplitGroup[] private _splitGroups;
    address private _projectOwner;
    address private _beneficiary;

    function setUp() public override {
        super.setUp();

        _nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));
        _controller = jbController();
        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _prices = jbPrices();
        __terminal = jbMultiTerminal();
        _tokens = jbTokens();
        _weight = 1000 * 10 ** 18;
        _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: 0,
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });
    }

    function launchProjectsForTestBelow() public returns (uint256, JBCurrencyAmount[] memory) {
        uint224 _nativePayoutLimit = 1 ether;
        uint256 _nativePricePerUsd = 0.0005 * 10 ** 18; // 1/2000
        // Will exceed the project's balance in the terminal.
        uint224 _usdPayoutLimit = uint224(mulDiv(1 ether, 10 ** 18, _nativePricePerUsd));

        // Package up fund access limits.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);

        _payoutLimits[0] =
            JBCurrencyAmount({amount: _nativePayoutLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});
        _payoutLimits[1] = JBCurrencyAmount({amount: _usdPayoutLimit, currency: uint32(uint160(address(usdcToken())))});
        _surplusAllowances[0] = JBCurrencyAmount({amount: 1 ether, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});
        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(__terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        // Package up ruleset config.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitGroups;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _tokensToAccept[1] = JBAccountingContext({
            token: address(usdcToken()),
            decimals: 6,
            currency: uint32(uint160(address(usdcToken())))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: __terminal, accountingContextsToAccept: _tokensToAccept});

        // Dummy.
        _controller.launchProjectFor({
            owner: address(420), //random
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        uint256 _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedNativeUsd = new MockPriceFeed(_nativePricePerUsd, 18);
        vm.label(address(_priceFeedNativeUsd), "Mock Price Feed Native-USD");

        _controller.addPriceFeed({
            projectId: _projectId,
            pricingCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            unitCurrency: uint32(uint160(address(usdcToken()))),
            feed: IJBPriceFeed(address(_priceFeedNativeUsd))
        });

        vm.stopPrank();

        return (_projectId, _payoutLimits);
    }

    function testAccessConstraintsDelineation() external {
        uint256 _nativePayAmount = 1.5 ether;
        uint256 _nativePayoutLimit = 1 ether;
        // Will exceed the project's balance in the terminal.

        (uint256 _projectId, JBCurrencyAmount[] memory _payoutLimits) = launchProjectsForTestBelow();

        __terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });

        uint256 initTerminalBalance = address(__terminal).balance;

        // Make sure the beneficiary has a balance of project tokens.
        assertEq(
            _tokens.totalBalanceOf(_beneficiary, _projectId),
            UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_weight)))
        );

        // First payout meets our native token limit.
        __terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _nativePayoutLimit,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            token: JBConstants.NATIVE_TOKEN, // Unused.
            minTokensPaidOut: 0
        });

        // Make sure the balance has changed, accounting for the fee that stays.
        assertEq(
            address(__terminal).balance,
            initTerminalBalance - _payoutLimits[0].amount
                + mulDiv(_payoutLimits[0].amount, __terminal.FEE(), JBConstants.MAX_FEE)
        );

        // Price for the amount (in USD) that can be paid out based on the terminal's current balance.
        uint256 _usdAmountAvailableToPayout = mulDiv(
            _nativePayAmount - _nativePayoutLimit, // native token value
            10 ** 18, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_amount.value`'s fidelity as possible
                // when converting.
            _prices.pricePerUnitOf({
                projectId: _projectId,
                pricingCurrency: _nativeCurrency,
                unitCurrency: uint32(uint160(address(usdcToken()))),
                decimals: 18
            })
        );

        /* vm.prank(address(__terminal));
        vm.expectRevert(abi.encodeWithSignature("INADEQUATE_TERMINAL_STORE_BALANCE()"));
        // Add 10000 to make up for the fidelity difference in prices. (0.0005/1)
        jbTerminalStore().recordPayoutFor(_projectId, _accountingContexts[1], _usdAmountAvailableToPayout + 10000,
        uint32(uint160(address(usdcToken())))); */

        // Should succeed with `_usdAmountAvailableToPayout`
        __terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _usdAmountAvailableToPayout,
            currency: uint32(uint160(address(usdcToken()))),
            token: JBConstants.NATIVE_TOKEN, // token
            minTokensPaidOut: 0
        });

        // Pay in another allotment.
        vm.deal(_beneficiary, _nativePayAmount);
        vm.prank(_beneficiary);

        __terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });

        /*  // Trying to pay out via the native token's payout limit will fail (currency is the native token or 1)
        vm.prank(address(__terminal));
        vm.expectRevert(abi.encodeWithSignature("PAYOUT_LIMIT_EXCEEDED()"));
        jbTerminalStore().recordPayoutFor(_projectId, _accountingContexts[0], 1, _nativeCurrency); */

        // But a payout via the USD limit will succeed
        __terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: _usdAmountAvailableToPayout,
            currency: uint32(uint160(address(usdcToken()))),
            token: JBConstants.NATIVE_TOKEN, //token (unused)
            minTokensPaidOut: 0
        });
    }

    function testFuzzedInvalidAllowanceCurrencyOrdering(uint24 ALLOWCURRENCY) external {
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](2);

        _payoutLimits[0] = JBCurrencyAmount({amount: 1, currency: _nativeCurrency});

        _surplusAllowances[0] = JBCurrencyAmount({amount: 1, currency: ALLOWCURRENCY});

        _surplusAllowances[1] = JBCurrencyAmount({amount: 1, currency: ALLOWCURRENCY == 0 ? 0 : ALLOWCURRENCY - 1});

        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(__terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);

        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitGroups;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        _projectOwner = multisig();

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](1);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: __terminal, accountingContextsToAccept: _tokensToAccept});

        vm.prank(_projectOwner);

        vm.expectRevert(JBFundAccessLimits.JBFundAccessLimits_InvalidSurplusAllowanceCurrencyOrdering.selector);

        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testFuzzedInvalidDistCurrencyOrdering(uint24 _payoutCurrency) external {
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);

        _payoutLimits[0] = JBCurrencyAmount({amount: 1, currency: _payoutCurrency});

        _payoutLimits[1] = JBCurrencyAmount({amount: 1, currency: _payoutCurrency == 0 ? 0 : _payoutCurrency - 1});

        _surplusAllowances[0] = JBCurrencyAmount({amount: 1, currency: JBCurrencyIds.USD});

        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(__terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);

        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitGroups;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        _projectOwner = multisig();

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _tokensToAccept[1] = JBAccountingContext({
            token: address(usdcToken()),
            decimals: 6,
            currency: uint32(uint160(address(usdcToken())))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: __terminal, accountingContextsToAccept: _tokensToAccept});

        vm.prank(_projectOwner);

        vm.expectRevert(JBFundAccessLimits.JBFundAccessLimits_InvalidPayoutLimitCurrencyOrdering.selector);

        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testFuzzedConfigureAccess(
        uint224 _payoutLimit,
        uint224 _surplusAllowance,
        uint32 _payoutCurrency,
        uint32 ALLOWCURRENCY
    )
        external
    {
        _payoutCurrency = uint32(bound(uint256(_payoutCurrency), uint256(0), type(uint24).max - 1));
        _payoutLimit = uint224(bound(uint256(_payoutLimit), uint232(1), uint224(type(uint24).max - 1)));
        _surplusAllowance = uint224(bound(uint256(_surplusAllowance), uint224(1), uint232(type(uint24).max - 1)));
        ALLOWCURRENCY = uint32(bound(uint256(ALLOWCURRENCY), uint256(0), type(uint24).max - 1));

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](2);

        _payoutLimits[0] = JBCurrencyAmount({amount: _payoutLimit, currency: _payoutCurrency});

        _payoutLimits[1] = JBCurrencyAmount({amount: _payoutLimit, currency: _payoutCurrency + 1});
        _surplusAllowances[0] = JBCurrencyAmount({amount: _surplusAllowance, currency: ALLOWCURRENCY});
        _surplusAllowances[1] = JBCurrencyAmount({amount: _surplusAllowance, currency: ALLOWCURRENCY + 1});
        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(__terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitGroups;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;
        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _tokensToAccept[1] = JBAccountingContext({
            token: address(usdcToken()),
            decimals: 6,
            currency: uint32(uint160(address(usdcToken())))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: __terminal, accountingContextsToAccept: _tokensToAccept});

        _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function test_RevertIf_MultipleDistroLimitCurrenciesOverLimit() external {
        uint256 _nativePayAmount = 1.5 ether;
        uint224 _nativePayoutLimit = 1 ether;
        uint256 _nativePricePerUsd = 5 * 10 ** 17; // 1/2000
        // Will exceed the project's balance in the terminal.
        uint224 _usdPayoutLimit = uint224(mulDiv(1 ether, 10 ** 18, _nativePricePerUsd));

        // Package up fund access limits.
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
        JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);

        _payoutLimits[0] = JBCurrencyAmount({amount: _nativePayoutLimit, currency: _nativeCurrency});
        _payoutLimits[1] = JBCurrencyAmount({amount: _usdPayoutLimit, currency: JBCurrencyIds.USD});
        _surplusAllowances[0] = JBCurrencyAmount({amount: 1, currency: JBCurrencyIds.USD});
        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(__terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: _surplusAllowances
        });

        // Package up ruleset config.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = _splitGroups;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _tokensToAccept[1] =
            JBAccountingContext({token: address(usdcToken()), decimals: 6, currency: JBCurrencyIds.USD});
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: __terminal, accountingContextsToAccept: _tokensToAccept});

        uint256 _projectId;
        {
            // Dummy.
            uint256 _dummyy = _controller.launchProjectFor({
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

            vm.startPrank(address(_projectOwner));
            _controller.addPriceFeed({
                projectId: _projectId,
                pricingCurrency: JBCurrencyIds.USD,
                unitCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                feed: IJBPriceFeed(address(new MockPriceFeed(_nativePricePerUsd, 18)))
            });
            _controller.addPriceFeed({
                projectId: _dummyy,
                pricingCurrency: JBCurrencyIds.USD,
                unitCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
                feed: IJBPriceFeed(address(new MockPriceFeed(_nativePricePerUsd, 18)))
            });
            vm.stopPrank();
        }

        __terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });

        // Make sure beneficiary has a balance of project tokens.
        uint256 _userTokenBalance = UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_weight)));
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _userTokenBalance);
        uint256 initTerminalBalance = address(__terminal).balance;

        vm.expectRevert(
            abi.encodeWithSelector(
                JBTerminalStore.JBTerminalStore_InadequateControllerPayoutLimit.selector, 1_800_000_000, 0
            )
        );
        // First payout should be fine based on price.
        __terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: 1_800_000_000,
            currency: JBCurrencyIds.USD,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            minTokensPaidOut: 0
        });

        uint256 _amountPaidOut = mulDiv(
            1_800_000_000,
            10 ** 18, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_amount.value`'s fidelity as possible
                // when converting.
            _prices.pricePerUnitOf({
                projectId: 1,
                pricingCurrency: JBCurrencyIds.USD,
                unitCurrency: _nativeCurrency,
                decimals: 18
            })
        );

        // Make sure the remaining balance is correct.
        assertApproxEqAbs(
            address(__terminal).balance,
            initTerminalBalance - mulDiv(_amountPaidOut, JBConstants.MAX_FEE, JBConstants.MAX_FEE + __terminal.FEE()),
            10_000_000_000
        );
    }

    function testMultipleDistroLimitCurrencies() external {
        uint256 _nativePayAmount = 3 ether;
        vm.deal(_beneficiary, _nativePayAmount);
        vm.prank(_beneficiary);

        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1 ether, currency: _nativeCurrency});
        _payoutLimits[1] = JBCurrencyAmount({amount: 2000 * 10 ** 18, currency: uint32(uint160(address(usdcToken())))});
        _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
            terminal: address(__terminal),
            token: JBConstants.NATIVE_TOKEN,
            payoutLimits: _payoutLimits,
            surplusAllowances: new JBCurrencyAmount[](0)
        });

        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);

        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].duration = 0;
        _rulesetConfig[0].weight = _weight;
        _rulesetConfig[0].weightCutPercent = 0;
        _rulesetConfig[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].fundAccessLimitGroups = _fundAccessLimitGroup;

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContext[] memory _tokensToAccept = new JBAccountingContext[](2);
        _tokensToAccept[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });
        _tokensToAccept[1] = JBAccountingContext({
            token: address(usdcToken()),
            decimals: 6,
            currency: uint32(uint160(address(usdcToken())))
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: __terminal, accountingContextsToAccept: _tokensToAccept});

        uint256 _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectUri: "myIPFSHash",
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });

        __terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "Take my money!",
            metadata: new bytes(0)
        });

        uint256 _price = 0.0005 * 10 ** 18; // 1/2000
        vm.startPrank(_projectOwner);
        MockPriceFeed _priceFeedNativeUsd = new MockPriceFeed(_price, 18);
        vm.label(address(_priceFeedNativeUsd), "Mock Price Feed MyToken-Native");

        _controller.addPriceFeed({
            projectId: _projectId,
            pricingCurrency: _nativeCurrency,
            unitCurrency: uint32(uint160(address(usdcToken()))),
            feed: _priceFeedNativeUsd
        });

        // Make sure the beneficiary has a balance of project tokens.
        uint256 _userTokenBalance = UD60x18unwrap(UD60x18mul(UD60x18wrap(_nativePayAmount), UD60x18wrap(_weight)));
        assertEq(_tokens.totalBalanceOf(_beneficiary, _projectId), _userTokenBalance);

        uint256 initTerminalBalance = address(__terminal).balance;
        uint256 ownerBalanceBeforeFirst = _projectOwner.balance;

        __terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: 3_000_000_000,
            currency: uint32(uint160(address(usdcToken()))),
            token: JBConstants.NATIVE_TOKEN, // Unused.
            minTokensPaidOut: 0
        });

        uint256 _amountPaidOut = mulDiv(
            3_000_000_000,
            10 ** 18, // Use `_MAX_FIXED_POINT_FIDELITY` to keep as much of the `_amount.value`'s fidelity as possible
                // when converting.
            _prices.pricePerUnitOf({
                projectId: 1,
                pricingCurrency: uint32(uint160(address(usdcToken()))),
                unitCurrency: _nativeCurrency,
                decimals: 18
            })
        );

        assertEq(
            _projectOwner.balance,
            ownerBalanceBeforeFirst + _amountPaidOut - mulDiv(_amountPaidOut, __terminal.FEE(), JBConstants.MAX_FEE)
        );

        // Funds leaving the ecosystem -> fee taken.
        assertEq(
            address(__terminal).balance,
            initTerminalBalance - _amountPaidOut + mulDiv(_amountPaidOut, __terminal.FEE(), JBConstants.MAX_FEE)
        );

        uint256 _balanceBeforeNativeDist = address(__terminal).balance;
        uint256 _ownerBalanceBeforeNativeDist = _projectOwner.balance;

        __terminal.sendPayoutsOf({
            projectId: _projectId,
            amount: 1 ether,
            currency: _nativeCurrency,
            token: JBConstants.NATIVE_TOKEN, // Unused.
            minTokensPaidOut: 0
        });

        // Funds leaving the ecosystem -> fee taken.
        assertEq(
            _projectOwner.balance,
            _ownerBalanceBeforeNativeDist + 1 ether - mulDiv(1 ether, __terminal.FEE(), JBConstants.MAX_FEE)
        );

        assertEq(
            address(__terminal).balance,
            _balanceBeforeNativeDist - 1 ether + mulDiv(1 ether, __terminal.FEE(), JBConstants.MAX_FEE)
        );
    }
}
