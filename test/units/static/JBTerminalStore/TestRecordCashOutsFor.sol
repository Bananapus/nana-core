// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordCashOutsFor_Local is JBTerminalStoreSetup {
    uint56 _projectId = 1;
    uint256 _decimals = 18;
    uint256 _balance = 10e18;
    uint256 _totalSupply = 20e18;
    uint256 _currentSurplus = 3e18;

    // Mocks
    IJBTerminal _terminal1 = IJBTerminal(makeAddr("terminal1"));
    IJBTerminal _terminal2 = IJBTerminal(makeAddr("terminal2"));
    IJBToken _token = IJBToken(makeAddr("token"));
    IJBController _controller = IJBController(makeAddr("controller"));
    IJBFundAccessLimits _accessLimits = IJBFundAccessLimits(makeAddr("funds"));
    IJBRulesetDataHook _dataHook = IJBRulesetDataHook(makeAddr("dataHook"));
    IJBCashOutHook _cashOutHook = IJBCashOutHook(makeAddr("cashOutHook"));

    uint32 _currency = uint32(uint160(address(_token)));
    address _nativeAddress = JBConstants.NATIVE_TOKEN;
    uint32 _nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));

    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenCurrentRulesetUseTotalSurplusForCashOutsEqTrue() {
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

        // return data for mock call
        IJBTerminal[] memory _terminals = new IJBTerminal[](2);
        _terminals[0] = _terminal1;
        _terminals[1] = _terminal2;

        // mock call to JBDirectory terminalsOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.terminalsOf, (_projectId));
        bytes memory _returned = abi.encode(_terminals);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal1Call = abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _decimals, _currency));
        bytes memory _terminal1Return = abi.encode(1e18);
        mockExpect(address(_terminal1), _terminal1Call, _terminal1Return);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal2Call = abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _decimals, _currency));
        bytes memory _terminal2Return = abi.encode(2e18);
        mockExpect(address(_terminal2), _terminal2Call, _terminal2Return);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
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
            useTotalSurplusForCashOuts: true,
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
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(_controller));
        _;
    }

    modifier whenCallerBalanceIsZero() {
        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(this), uint256(0)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(0);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(_balanceCallReturn, 0);

        // return data for mock call
        IJBTerminal[] memory _terminals = new IJBTerminal[](2);
        _terminals[0] = _terminal1;
        _terminals[1] = _terminal2;

        // mock call to JBDirectory terminalsOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.terminalsOf, (_projectId));
        bytes memory _returned = abi.encode(_terminals);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal1Call = abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _decimals, _currency));
        bytes memory _terminal1Return = abi.encode(1e18);
        mockExpect(address(_terminal1), _terminal1Call, _terminal1Return);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal2Call = abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _decimals, _currency));
        bytes memory _terminal2Return = abi.encode(2e18);
        mockExpect(address(_terminal2), _terminal2Call, _terminal2Return);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
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
            useTotalSurplusForCashOuts: true,
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
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(_controller));
        _;
    }

    modifier whenCurrentRulesetUseTotalSurplusForCashOutsEqTrueWithHook() {
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

        // return data for mock call
        IJBTerminal[] memory _terminals = new IJBTerminal[](2);
        _terminals[0] = _terminal1;
        _terminals[1] = _terminal2;

        // mock call to JBDirectory terminalsOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.terminalsOf, (_projectId));
        bytes memory _returned = abi.encode(_terminals);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal1Call = abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _decimals, _currency));
        bytes memory _terminal1Return = abi.encode(1e18);
        mockExpect(address(_terminal1), _terminal1Call, _terminal1Return);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal2Call = abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _decimals, _currency));
        bytes memory _terminal2Return = abi.encode(2e18);
        mockExpect(address(_terminal2), _terminal2Call, _terminal2Return);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: false,
            useDataHookForCashOut: true,
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
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(_controller));

        _;
    }

    function test_GivenTheCashOutCountGtTotalSupply() external whenCurrentRulesetUseTotalSurplusForCashOutsEqTrue {
        // it will revert INSUFFICIENT_TOKENS

        uint256 _supply = 1e18;

        // mock JBController totalTokenSupplyWithReservedTokensOf
        mockExpect(
            address(_controller),
            abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId)),
            abi.encode(_supply)
        );

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // call params
        JBAccountingContext memory _accountingContexts =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});
        JBAccountingContext[] memory _balanceContexts = new JBAccountingContext[](1);

        _balanceContexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        uint256 _cashOutCount = 4e18; // greater than token total supply

        vm.expectRevert(
            abi.encodeWithSelector(JBTerminalStore.JBTerminalStore_InsufficientTokens.selector, _cashOutCount, _supply)
        );
        _store.recordCashOutFor({
            holder: address(this),
            projectId: _projectId,
            cashOutCount: _cashOutCount,
            accountingContext: _accountingContexts,
            balanceAccountingContexts: _balanceContexts,
            metadata: ""
        });
    }

    function test_GivenTheCurrentSurplusGtZero() external whenCurrentRulesetUseTotalSurplusForCashOutsEqTrue {
        // it will set reclaim amount using the currentSurplus

        // mock JBController totalTokenSupplyWithReservedTokensOf
        mockExpect(
            address(_controller),
            abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId)),
            abi.encode(_totalSupply)
        );

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // call params
        JBAccountingContext memory _accountingContexts =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});
        JBAccountingContext[] memory _balanceContexts = new JBAccountingContext[](1);

        _balanceContexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        uint256 _cashOutCount = 6; // within balance bounds
        uint256 expectedCashOuts = mulDiv(3e18, _cashOutCount, _totalSupply);

        (, uint256 reclaimed,,) = _store.recordCashOutFor({
            holder: address(this),
            projectId: _projectId,
            cashOutCount: _cashOutCount,
            accountingContext: _accountingContexts,
            balanceAccountingContexts: _balanceContexts,
            metadata: ""
        });

        assertEq(expectedCashOuts, reclaimed);
    }

    function test_GivenCurrentRulesetUseDataHookForCashOutEqTrue()
        external
        whenCurrentRulesetUseTotalSurplusForCashOutsEqTrueWithHook
    {
        // it will call the dataHook for the reclaim amount and hookSpecs

        // mock JBController totalTokenSupplyWithReservedTokensOf
        mockExpect(
            address(_controller),
            abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId)),
            abi.encode(_totalSupply)
        );

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // call params
        JBAccountingContext memory _accountingContexts =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});
        JBAccountingContext[] memory _balanceContexts = new JBAccountingContext[](1);

        _balanceContexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        uint256 _cashOutCount = 1e18; // within balance bounds
        uint256 expectedCashOuts = mulDiv(3e18, _cashOutCount, _totalSupply);

        // Create the struct that describes the amount being reclaimed.
        JBTokenAmount memory _reclaimedTokenAmount = JBTokenAmount({
            token: _accountingContexts.token,
            value: 3e18,
            decimals: _accountingContexts.decimals,
            currency: _accountingContexts.currency
        });

        // Create the cash out context that'll be sent to the data hook.
        JBBeforeCashOutRecordedContext memory _context = JBBeforeCashOutRecordedContext({
            terminal: address(this),
            holder: address(this),
            projectId: _projectId,
            rulesetId: uint48(block.timestamp),
            cashOutCount: _cashOutCount,
            totalSupply: _totalSupply,
            surplus: _reclaimedTokenAmount,
            useTotalSurplus: true,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            metadata: ""
        });

        // return data
        JBCashOutHookSpecification[] memory _spec = new JBCashOutHookSpecification[](1);
        _spec[0] = JBCashOutHookSpecification({hook: _cashOutHook, amount: 0, metadata: ""});

        // mock call to data hook beforeCashOutRecordedWith
        mockExpect(
            address(_dataHook),
            abi.encodeCall(IJBRulesetDataHook.beforeCashOutRecordedWith, (_context)),
            abi.encode(JBConstants.MAX_CASH_OUT_TAX_RATE, 1e18, _totalSupply, _spec)
        );

        uint256 balanceBefore = _store.balanceOf(address(this), _projectId, _accountingContexts.token);

        (, uint256 reclaimed,,) = _store.recordCashOutFor({
            holder: address(this),
            projectId: _projectId,
            cashOutCount: _cashOutCount,
            accountingContext: _accountingContexts,
            balanceAccountingContexts: _balanceContexts,
            metadata: ""
        });

        // covers GivenTheBalanceDiffGtZero()
        assertEq(
            balanceBefore - expectedCashOuts, _store.balanceOf(address(this), _projectId, _accountingContexts.token)
        );

        assertEq(expectedCashOuts, reclaimed);
    }

    function test_GivenTheAmountReclaimedGtCallerBalance() external whenCallerBalanceIsZero {
        // it will revert INADEQUATE_TERMINAL_STORE_BALANCE

        uint256 _totalTokens = 10e18;

        // mock JBController totalTokenSupplyWithReservedTokensOf
        mockExpect(
            address(_controller),
            abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId)),
            abi.encode(_totalTokens)
        );

        // call params
        JBAccountingContext memory _accountingContexts =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});
        JBAccountingContext[] memory _balanceContexts = new JBAccountingContext[](1);

        _balanceContexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        uint256 _cashOutCount = 4e18; // greater than caller balance

        uint256 reclaimAmount = mulDiv(_currentSurplus, _cashOutCount, _totalTokens);

        vm.expectRevert(
            abi.encodeWithSelector(
                JBTerminalStore.JBTerminalStore_InadequateTerminalStoreBalance.selector, reclaimAmount, 0
            )
        );
        _store.recordCashOutFor({
            holder: address(this),
            projectId: _projectId,
            cashOutCount: _cashOutCount,
            accountingContext: _accountingContexts,
            balanceAccountingContexts: _balanceContexts,
            metadata: ""
        });
    }

    // Probably unnecessary even though it may give us a bit of cov %.. skipping for now
    /* function test_WhenTheCurrentRulesetUseTotalSurplusForCashOutsEqFalse() external {
        // it will use the standard surplus calculation
    } */
}
