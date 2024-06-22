// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordUsedAllowanceOf_Local is JBTerminalStoreSetup {
    uint256 _projectId = 1;
    uint256 _decimals = 18;
    uint256 _defaultAmount = 1e18;
    uint256 _balance = 10e18;
    uint256 _payoutLimit = 2e18;

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));
    IJBController _controller = IJBController(makeAddr("controller"));
    IJBFundAccessLimits _accessLimits = IJBFundAccessLimits(makeAddr("funds"));

    uint32 _currency = uint32(uint160(address(_token)));
    address _nativeAddress = JBConstants.NATIVE_TOKEN;
    uint32 _nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));

    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenAmountIsWithinRangeToUseSurplusAllowance() {
        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(this), uint256(1)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(_nativeAddress)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
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
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.controllerOf, (_projectId));
        bytes memory _returned = abi.encode(_controller);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to get JBFundAccessLimits address
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        // mock call to JBFundAccessLimits surplusAllowanceOf
        mockExpect(
            address(_accessLimits),
            abi.encodeCall(
                IJBFundAccessLimits.surplusAllowanceOf,
                (_projectId, block.timestamp, address(this), address(_token), _currency)
            ),
            abi.encode(1e19)
        );

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(this), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        _;
    }

    function test_GivenCallingCurrencyEqAccountingCurrency() external whenAmountIsWithinRangeToUseSurplusAllowance {
        // it will not convert prices

        // setup calldata
        JBAccountingContext memory _context =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        (, uint256 usedAmount) = _store.recordUsedAllowanceOf(_projectId, _context, _defaultAmount, _currency);
        assertEq(usedAmount, _defaultAmount);
    }

    function test_GivenCallingCurrencyDneqAccountingCurrency() external {
        // it will convert prices

        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(this), uint256(1)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_nativeAddress), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(this), _projectId, address(_nativeAddress));
        assertEq(_balanceCallReturn, _balance);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(_nativeAddress)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
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
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(_controller));

        // mock call to get JBFundAccessLimits address
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        // mock call to JBFundAccessLimits surplusAllowanceOf
        mockExpect(
            address(_accessLimits),
            abi.encodeCall(
                IJBFundAccessLimits.surplusAllowanceOf,
                (_projectId, block.timestamp, address(this), address(_nativeAddress), _currency)
            ),
            abi.encode(1e19)
        );

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](2);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});
        _limits[1] = JBCurrencyAmount({amount: 0, currency: _nativeCurrency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        mockExpect(
            address(_accessLimits),
            abi.encodeCall(
                IJBFundAccessLimits.payoutLimitsOf,
                (_projectId, block.timestamp, address(this), address(_nativeAddress))
            ),
            abi.encode(_limits)
        );

        // mock call to JBPrices pricePerUnitOf
        bytes memory _pricePerCall =
            abi.encodeCall(IJBPrices.pricePerUnitOf, (_projectId, _currency, _nativeCurrency, 18));
        mockExpect(address(prices), _pricePerCall, abi.encode(1e18));

        // setup calldata
        JBAccountingContext memory _context =
            JBAccountingContext({token: address(_nativeAddress), decimals: 18, currency: _nativeCurrency});

        // price is 1:1
        (, uint256 usedAmount) = _store.recordUsedAllowanceOf(_projectId, _context, _defaultAmount, _currency);
        assertEq(usedAmount, _defaultAmount);
    }

    function test_GivenThereIsInadequateBalance() external {
        // it will revert INADEQUATE_TERMINAL_STORE_BALANCE

        // do not set a balance (will be zero)
        /* // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(this), uint256(1)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance); */

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(_currency)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
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
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.controllerOf, (_projectId));
        bytes memory _returned = abi.encode(_controller);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to get JBFundAccessLimits address
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        // mock call to JBFundAccessLimits surplusAllowanceOf
        mockExpect(
            address(_accessLimits),
            abi.encodeCall(
                IJBFundAccessLimits.surplusAllowanceOf,
                (_projectId, block.timestamp, address(this), address(_token), _currency)
            ),
            abi.encode(1e19)
        );

        JBCurrencyAmount[] memory _limits = new JBCurrencyAmount[](1);
        _limits[0] = JBCurrencyAmount({amount: 0, currency: _currency});

        // mock JBFundAccessLimits call to payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(this), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_limits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // setup calldata
        JBAccountingContext memory _context =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        vm.expectRevert(abi.encodeWithSignature("INADEQUATE_TERMINAL_STORE_BALANCE()"));
        _store.recordUsedAllowanceOf(_projectId, _context, _defaultAmount, _currency);
    }

    function test_WhenAmountIsNotWithinRangeToUseSurplusAllowance() external {
        // it will revert INADEQUATE_CONTROLLER_ALLOWANCE

        // set usedSurplusAllowanceOf to be too high for the subsequent call to succeed
        // Find the storage slot
        bytes32 usedSurplusOfSlot = keccak256(abi.encode(address(this), uint256(3)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(usedSurplusOfSlot)));
        bytes32 tokenSlot = keccak256(abi.encode(address(_token), uint256(projectSlot)));
        bytes32 rulesetSlot = keccak256(abi.encode(block.timestamp, uint256(tokenSlot)));
        bytes32 slot = keccak256(abi.encode(_currency, uint256(rulesetSlot)));

        bytes32 usedSurplus = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, usedSurplus);

        // Ensure balance is set correctly
        uint256 _usedSurplusCallReturn =
            _store.usedSurplusAllowanceOf(address(this), _projectId, address(_token), block.timestamp, _currency);
        assertEq(_usedSurplusCallReturn, _balance);

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(_currency)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: false,
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
            cycleNumber: uint48(block.timestamp),
            id: uint48(block.timestamp),
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: uint32(block.timestamp + 1000),
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata
        });

        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.controllerOf, (_projectId));
        bytes memory _returned = abi.encode(_controller);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to get JBFundAccessLimits address
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        // mock call to JBFundAccessLimits surplusAllowanceOf
        mockExpect(
            address(_accessLimits),
            abi.encodeCall(
                IJBFundAccessLimits.surplusAllowanceOf,
                (_projectId, block.timestamp, address(this), address(_token), _currency)
            ),
            abi.encode(1e19)
        );

        // setup calldata
        JBAccountingContext memory _context =
            JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        vm.expectRevert(abi.encodeWithSignature("INADEQUATE_CONTROLLER_ALLOWANCE()"));
        _store.recordUsedAllowanceOf(_projectId, _context, _defaultAmount, _currency);
    }
}
