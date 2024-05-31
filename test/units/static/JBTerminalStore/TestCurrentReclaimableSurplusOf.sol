// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

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

    function test_WhenUseTotalSurplusEqTrue() external {
        // it will use the total surplus of all terminals
    }

    modifier whenProjectHasBalance() {
        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(_terminal), uint256(1)));
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
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(_controller));

        // mock call to controller FUND_ACCESS_LIMITS
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        uint256 reclaimable = _store.currentReclaimableSurplusOf(
            address(_terminal), _projectId, _contexts, 18, _currency, _tokenCount, false
        );
        assertEq(0, reclaimable);
    }

    modifier whenUseTotalSurplusEqFalse() {
        _;
    }

    function test_GivenCurrentSurplusGtZero() external whenUseTotalSurplusEqFalse whenProjectHasBalance {
        // it will get the number of outstanding tokens and return the reclaimable surplus

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
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

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(1e18);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        uint256 reclaimable =
            _store.currentReclaimableSurplusOf(address(_terminal), _projectId, _contexts, 18, _currency, 1e18, false);
        uint256 assumed = mulDiv((1e18 - 1e17), _tokenCount, 1e18);

        assertEq(assumed, reclaimable);
    }

    function test_GivenTokenCountIsEqToTotalSupply() external whenUseTotalSurplusEqFalse whenProjectHasBalance {
        // it will return the rest of the surplus

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
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

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(1e18);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        uint256 reclaimable = _store.currentReclaimableSurplusOf(
            address(_terminal), _projectId, _contexts, 18, _currency, _tokenCount, false
        );

        assertEq(_tokenCount, reclaimable);
    }

    function test_GivenRedemptionRateEqZero() external whenUseTotalSurplusEqFalse whenProjectHasBalance {
        // it will return zero

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
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

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(1e18);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        uint256 reclaimable = _store.currentReclaimableSurplusOf(
            address(_terminal), _projectId, _contexts, 18, _currency, _tokenCount, false
        );

        assertEq(0, reclaimable);
    }

    function test_GivenRedemptionRateDneqMAX_REDEMPTION_RATE()
        external
        whenUseTotalSurplusEqFalse
        whenProjectHasBalance
    {
        // it will return the calculated proportion

        // setup calldata
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);
        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
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

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // mock JBController totalTokenSupplyWithReservedTokensOf
        bytes memory _totalTokenCall = abi.encodeCall(IJBController.totalTokenSupplyWithReservedTokensOf, (_projectId));
        bytes memory _tokenTotal = abi.encode(1e18);
        mockExpect(address(_controller), _totalTokenCall, _tokenTotal);

        uint256 assumed = mulDiv(
            1e18 - 1e17,
            5000 + mulDiv(_tokenCount, JBConstants.MAX_REDEMPTION_RATE - 5000, 1e18),
            JBConstants.MAX_REDEMPTION_RATE
        );

        uint256 reclaimable = _store.currentReclaimableSurplusOf(
            address(_terminal), _projectId, _contexts, 18, _currency, _tokenCount, false
        );

        assertEq(assumed, reclaimable);
    }

    function test_GivenNotOverloaded() external whenProjectHasBalance {
        // it will get the current ruleset and proceed to return reclaimable as above

        // Params
        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
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

        uint256 _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

        // JBRulesets return calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        uint256 reclaimable = _store.currentReclaimableSurplusOf(_projectId, _tokenCount, 1e18, 1e18);
        assertEq(1e18, reclaimable);
    }
}
