// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";
import {JBCashOuts} from "../../../../src/libraries/JBCashOuts.sol";

contract TestCurrentReclaimableSurplusOf_Local is JBTerminalStoreSetup {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    uint256 _projectId = 1;
    uint256 _balance = 1e18;

    // Mocks
    IJBTerminal _terminal = IJBTerminal(makeAddr("terminal"));
    IJBToken _token = IJBToken(makeAddr("token"));
    IJBController _controller = IJBController(makeAddr("controller"));
    IJBFundAccessLimits _accessLimits = IJBFundAccessLimits(makeAddr("funds"));

    uint32 _currency = uint32(uint160(address(_token)));
    uint256 _tokenCount = 1e18;

    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenProjectHasBalance() {
        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(_terminal), uint256(0)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(_terminal), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance);
        _;
    }

    function test_GivenCurrentSurplusEqZero() external {
        // it will return zero

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

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
            metadata: 0
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock current surplus as zero
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _contexts, 18, _currency)),
            abi.encode(0)
        );

        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminal;
        uint256 reclaimable =
            _store.currentReclaimableSurplusOf(_projectId, _tokenCount, _terminals, _contexts, 18, _currency);
        assertEq(0, reclaimable);
    }

    function test_GivenCurrentSurplusGtZero() external whenProjectHasBalance {
        // it will get the number of outstanding tokens and return the reclaimable surplus

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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

        // "mock" payout amount since the currentSurplusOf call is mocked
        uint224 _payout = 1e17;
        uint256 _supply = 1e19;
        uint256 _cashoutAmount = 1e18;

        // surplus call to the terminal
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _contexts, 18, _currency)),
            abi.encode(_supply - _payout)
        );

        // mock JBController totalTokenSupplyWithReservedTokensOf
        mockExpect(
            address(_controller),
            abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId)),
            abi.encode(_supply)
        );

        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminal;
        uint256 reclaimable =
            _store.currentReclaimableSurplusOf(_projectId, _cashoutAmount, _terminals, _contexts, 18, _currency);

        // The above call should be calculating the reclaimable amount as we are here, so they will be congruent.
        uint256 assumed =
            JBCashOuts.cashOutFrom(_supply - _payout, _cashoutAmount, _supply, JBConstants.MAX_CASH_OUT_TAX_RATE / 2);

        assertEq(assumed, reclaimable);
    }

    function test_GivenTokenCountIsEqToTotalSupply() external whenProjectHasBalance {
        // it will return the rest of the surplus

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
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

        // mock call to get cumulative surplus
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _contexts, 18, _currency)),
            abi.encode(_tokenCount)
        );

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(_tokenCount);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminal;
        uint256 reclaimable =
            _store.currentReclaimableSurplusOf(_projectId, _tokenCount, _terminals, _contexts, 18, _currency);

        // The tokenCount is equal to the total supply, so the reclaimable amount will be the same as the supply. We
        // couldn't reclaim more.
        assertEq(_tokenCount, reclaimable);
    }

    function test_GivenCashOutTaxRateEqZero() external whenProjectHasBalance {
        // it will return zero

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE, // no surplus can be reclaimed.
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

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(1e18);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        // mock current surplus
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _contexts, 18, _currency)),
            abi.encode(1e18)
        );

        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminal;
        uint256 reclaimable =
            _store.currentReclaimableSurplusOf(_projectId, _tokenCount, _terminals, _contexts, 18, _currency);

        // No surplus can be reclaimed.
        assertEq(0, reclaimable);
    }

    function test_GivenCashOutRateDneqMAX_CASH_OUT_RATE() external whenProjectHasBalance {
        // it will return the calculated proportion

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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

        // mock current surplus
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.currentSurplusOf, (_projectId, _contexts, 18, _currency)),
            abi.encode(1e18)
        );

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(1e18);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        uint256 reclaimable;
        {
            IJBTerminal[] memory _terminals = new IJBTerminal[](1);
            _terminals[0] = _terminal;
            reclaimable =
                _store.currentReclaimableSurplusOf(_projectId, _tokenCount, _terminals, _contexts, 18, _currency);
        }

        uint256 assumed = mulDiv(
            1e18,
            5000 + mulDiv(_tokenCount, JBConstants.MAX_CASH_OUT_TAX_RATE - 5000, 1e18),
            JBConstants.MAX_CASH_OUT_TAX_RATE
        );

        assertEq(assumed, reclaimable);
    }

    function test_GivenNotOverloaded() external whenProjectHasBalance {
        // it will get the current ruleset and proceed to return reclaimable as above

        // Params
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE / 2,
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

        uint256 reclaimable = _store.currentReclaimableSurplusOf(_projectId, _tokenCount, 1e18, 1e18);
        assertEq(1e18, reclaimable);
    }
}
