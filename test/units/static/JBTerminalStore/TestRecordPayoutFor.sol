// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordPayoutFor_Local is JBTerminalStoreSetup {
    // A library that parses the packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    uint256 _projectId = 1;
    uint256 _defaultValue = 1e18;
    uint256 _balance = 1e18;

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));
    IJBController _controller = IJBController(makeAddr("controller"));
    IJBFundAccessLimits _accessLimits = IJBFundAccessLimits(makeAddr("funds"));

    uint32 _currency = uint32(uint160(address(_token)));
    uint32 _nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));

    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenThereIsAZeroUsedPayoutLimitOfTheSenderForCurrentRuleset() {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            baseCurrency: uint32(uint160(address(_token))),
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

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(_controller));

        // mock call to controller FUND_ACCESS_LIMITS
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        _;
    }

    modifier whenThereIsAZeroUsedPayoutLimitOfTheSenderForCurrentRulesetAndAccessLimitsIsntCalled() {
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            baseCurrency: uint32(uint160(address(_token))),
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

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        /* // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)),
        abi.encode(_controller));

        // mock call to controller FUND_ACCESS_LIMITS
        mockExpect(
        address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        ); */

        _;
    }

    function test_GivenTheCallingAmountGtWhatIsAvailableToPayout()
        external
        whenThereIsAZeroUsedPayoutLimitOfTheSenderForCurrentRulesetAndAccessLimitsIsntCalled
    {
        // it will revert JBTerminalStore_InadequateTerminalStoreBalance

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        vm.expectRevert(
            abi.encodeWithSelector(
                JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector, _defaultValue, 0
            )
        );
        _store.recordPayoutFor(_projectId, _contexts[0], _defaultValue, _currency);
    }

    function test_GivenTheCallingCurrencyEqTheContextCurrency()
        external
        whenThereIsAZeroUsedPayoutLimitOfTheSenderForCurrentRuleset
    {
        // it will not convert prices, update balances and return

        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(this), uint256(0)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance);

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        // mock call to JBFundAccessLimits payoutLimitOf
        bytes memory _payoutsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitOf, (_projectId, block.timestamp, address(this), address(_token), _currency)
        );

        bytes memory _payoutsReturn = abi.encode(_defaultValue);
        mockExpect(address(_accessLimits), _payoutsCall, _payoutsReturn);

        uint256 balanceBefore = _store.balanceOf(address(this), _projectId, address(_token));

        (, uint256 amountPaid) = _store.recordPayoutFor(_projectId, _contexts[0], _defaultValue, _currency);
        assertEq(amountPaid, _defaultValue);

        // check usedPayoutLimit updated correctly
        uint256 usedAfter =
            _store.usedPayoutLimitOf(address(this), _projectId, address(_token), block.timestamp, _currency);
        assertEq(usedAfter, _defaultValue);

        // check balance updated correctly
        uint256 expectedBalanceAfter = balanceBefore - _defaultValue;
        uint256 balanceAfter = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(balanceAfter, expectedBalanceAfter);
    }

    function test_GivenTheCallingCurrencyDneqTheContextCurrency()
        external
        whenThereIsAZeroUsedPayoutLimitOfTheSenderForCurrentRuleset
    {
        // it will convert prices and return

        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(this), uint256(0)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance);

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _nativeCurrency});

        // mock call to JBFundAccessLimits payoutLimitOf
        bytes memory _payoutsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitOf, (_projectId, block.timestamp, address(this), address(_token), _currency)
        );

        bytes memory _payoutsReturn = abi.encode(_defaultValue);
        mockExpect(address(_accessLimits), _payoutsCall, _payoutsReturn);

        // mock call to JBPrices pricePerUnitOf
        bytes memory _pricesCall =
            abi.encodeCall(IJBPrices.pricePerUnitOf, (_projectId, _currency, _nativeCurrency, 18));
        bytes memory _pricesReturn = abi.encode(2e18);
        mockExpect(address(prices), _pricesCall, _pricesReturn);

        (, uint256 amountPaid) = _store.recordPayoutFor(_projectId, _contexts[0], _defaultValue, _currency);
        assertEq(amountPaid, _defaultValue / 2);
    }

    function test_GivenTheAmountPaidOutExceedsBalance()
        external
        whenThereIsAZeroUsedPayoutLimitOfTheSenderForCurrentRulesetAndAccessLimitsIsntCalled
    {
        // it will revert INADEQUATE_TERMINAL_STORE_BALANCE

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        vm.expectRevert(
            abi.encodeWithSelector(
                JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector, _defaultValue, 0
            )
        );
        _store.recordPayoutFor(_projectId, _contexts[0], _defaultValue, _currency);
    }
}
