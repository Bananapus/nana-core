// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordPaymentFrom_Local is JBTerminalStoreSetup {
    // A library that parses the packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    uint56 _projectId = 1;
    uint256 _defaultValue = 1e18;
    uint8 _defaultDecimals = 18;

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));
    IJBRulesetDataHook _dataHook = IJBRulesetDataHook(makeAddr("dataHook"));
    IJBPayHook _payHook = IJBPayHook(makeAddr("payHook"));

    uint32 _currency = uint32(uint160(address(_token)));
    uint32 _nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));

    function setUp() public {
        super.terminalStoreSetup();
    }

    function test_WhenCurrentRulesetCycleNumberIsZero() external {
        // it will revert INVALID_RULESET

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: 0,
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        vm.expectRevert(JBTerminalStore.JBTerminalStore_RulesetNotFound.selector);
        _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });
    }

    function test_WhenCurrentRulesetPausePayEqTrue() external {
        // it will revert RULESET_PAYMENT_PAUSED

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: true,
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: false,
            useDataHookForCashOut: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        vm.expectRevert(JBTerminalStore.JBTerminalStore_RulesetPaymentPaused.selector);
        _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });
    }

    modifier whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress() {
        _;
    }

    function test_GivenTheHookReturnsANonZeroSpecifiedAmount()
        external
        whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress
    {
        // it will decrement the amount being added to the local balance

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(address(_token))),
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: true,
            useDataHookForCashOut: false,
            dataHook: address(_dataHook),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // params for data hook beforePayRecordedWith
        JBBeforePayRecordedContext memory _context = JBBeforePayRecordedContext({
            terminal: address(this),
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            rulesetId: uint48(block.timestamp),
            beneficiary: address(this),
            weight: _returnedRuleset.weight,
            reservedPercent: _returnedRuleset.reservedPercent(),
            metadata: ""
        });

        // return data
        JBPayHookSpecification[] memory _spec = new JBPayHookSpecification[](1);
        _spec[0] = JBPayHookSpecification({hook: _payHook, amount: _defaultValue / 2, metadata: ""});

        // mock call to the configured JBRulesetDataHook beforePayRecordedWith
        bytes memory _beforePayCall = abi.encodeCall(IJBRulesetDataHook.beforePayRecordedWith, (_context));
        bytes memory _beforePayReturn = abi.encode(1e18 / 2, _spec);
        mockExpect(address(_dataHook), _beforePayCall, _beforePayReturn);

        (, uint256 tokenCount,) = _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });

        assertEq(tokenCount, 1e18 / 2);
    }

    function test_GivenTheHookReturnsInvalidSpecifiedAmount()
        external
        whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress
    {
        // it will revert INVALID_AMOUNT_TO_SEND_HOOK

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(address(_token))),
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: true,
            useDataHookForCashOut: false,
            dataHook: address(_dataHook),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // params for data hook beforePayRecordedWith
        JBBeforePayRecordedContext memory _context = JBBeforePayRecordedContext({
            terminal: address(this),
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            rulesetId: uint48(block.timestamp),
            beneficiary: address(this),
            weight: _returnedRuleset.weight,
            reservedPercent: _returnedRuleset.reservedPercent(),
            metadata: ""
        });

        // return data
        JBPayHookSpecification[] memory _spec = new JBPayHookSpecification[](1);
        _spec[0] = JBPayHookSpecification({hook: _payHook, amount: _defaultValue * 2, metadata: ""});

        // mock call to the configured JBRulesetDataHook beforePayRecordedWith
        bytes memory _beforePayCall = abi.encodeCall(IJBRulesetDataHook.beforePayRecordedWith, (_context));
        bytes memory _beforePayReturn = abi.encode(1e18 / 2, _spec);
        mockExpect(address(_dataHook), _beforePayCall, _beforePayReturn);

        vm.expectRevert(
            abi.encodeWithSelector(
                JBTerminalStore.JBTerminalStore_InvalidAmountToForwardHook.selector,
                _defaultValue * 2,
                _tokenAmount.value
            )
        );
        _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });
    }

    function test_GivenWeightReturnedByTheHookIsZero()
        external
        whenCurrentRulesetUseDataHookForPayEqTrueAndTheHookDneqZeroAddress
    {
        // it will return zero as the tokenCount

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(address(_token))),
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: true,
            useDataHookForCashOut: false,
            dataHook: address(_dataHook),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // params for data hook beforePayRecordedWith
        JBBeforePayRecordedContext memory _context = JBBeforePayRecordedContext({
            terminal: address(this),
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            rulesetId: uint48(block.timestamp),
            beneficiary: address(this),
            weight: _returnedRuleset.weight,
            reservedPercent: _returnedRuleset.reservedPercent(),
            metadata: ""
        });

        // return data
        JBPayHookSpecification[] memory _spec = new JBPayHookSpecification[](1);
        _spec[0] = JBPayHookSpecification({hook: _payHook, amount: _defaultValue / 2, metadata: ""});

        // mock call to the configured JBRulesetDataHook beforePayRecordedWith
        bytes memory _beforePayCall = abi.encodeCall(IJBRulesetDataHook.beforePayRecordedWith, (_context));
        bytes memory _beforePayReturn = abi.encode(0, _spec);
        mockExpect(address(_dataHook), _beforePayCall, _beforePayReturn);

        (, uint256 tokenCount,) = _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });

        assertEq(tokenCount, 0);
    }

    function test_WhenAHookIsNotConfigured() external {
        // it will derive weight from the ruleset

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(address(_token))),
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: true,
            useDataHookForCashOut: false,
            // hook not configured
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // return data
        JBPayHookSpecification[] memory _spec = new JBPayHookSpecification[](1);
        _spec[0] = JBPayHookSpecification({hook: _payHook, amount: _defaultValue / 2, metadata: ""});

        (, uint256 tokenCount,) = _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });

        assertEq(tokenCount, 1e18);
    }

    function test_WhenTheTerminalShouldBaseItsWeightOnACurrencyOtherThanTheRulesetweightCurrency() external {
        // it will return an adjusted weightRatio

        // call params
        JBTokenAmount memory _tokenAmount = JBTokenAmount({
            token: address(_token),
            value: _defaultValue,
            decimals: _defaultDecimals,
            currency: _currency
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: _nativeCurrency,
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
            useTotalSurplusForCashOuts: false,
            useDataHookForPay: true,
            useDataHookForCashOut: false,
            dataHook: address(_dataHook),
            metadata: 0
        });

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // params for data hook beforePayRecordedWith
        JBBeforePayRecordedContext memory _context = JBBeforePayRecordedContext({
            terminal: address(this),
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            rulesetId: uint48(block.timestamp),
            beneficiary: address(this),
            weight: _returnedRuleset.weight,
            reservedPercent: _returnedRuleset.reservedPercent(),
            metadata: ""
        });

        // return data
        JBPayHookSpecification[] memory _spec = new JBPayHookSpecification[](1);
        _spec[0] = JBPayHookSpecification({hook: _payHook, amount: _defaultValue / 2, metadata: ""});

        // mock call to the configured JBRulesetDataHook beforePayRecordedWith
        mockExpect(
            address(_dataHook),
            abi.encodeCall(IJBRulesetDataHook.beforePayRecordedWith, (_context)),
            abi.encode(1e18 / 2, _spec)
        );

        // mock call to JBPrices pricePerUnitOf
        bytes memory _pricePerCall =
            abi.encodeCall(IJBPrices.pricePerUnitOf, (_projectId, _currency, _nativeCurrency, 18));
        bytes memory _pricePerReturn = abi.encode(2e18);
        mockExpect(address(prices), _pricePerCall, _pricePerReturn);

        uint256 expectedCount = mulDiv(_defaultValue, 1e18 / 2, 2e18);

        (, uint256 tokenCount,) = _store.recordPaymentFrom({
            payer: address(this),
            amount: _tokenAmount,
            projectId: _projectId,
            beneficiary: address(this),
            metadata: ""
        });

        assertEq(tokenCount, expectedCount);
    }
}
