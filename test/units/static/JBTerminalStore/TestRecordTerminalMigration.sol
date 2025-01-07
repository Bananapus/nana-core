// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestRecordTerminalMigration_Local is JBTerminalStoreSetup {
    uint256 _projectId = 1;
    uint256 _balance = 1e19;

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));

    function setUp() public {
        super.terminalStoreSetup();
    }

    function test_WhenRulesetAllowsMigration() external {
        // it will return the current balance and reset balance to zero

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

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: true,
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

        // It will return the balance before migration
        uint256 balanceReturned = _store.recordTerminalMigration(_projectId, address(_token));
        assertEq(balanceReturned, _balance);

        // Then it will set the balance to zero
        uint256 resetBalance = _store.balanceOf(address(this), _projectId, address(_token));
        assertEq(resetBalance, 0);
    }

    function test_WhenRulesetDnAllowMigration() external {
        // it will revert TERMINAL_MIGRATION_NOT_ALLOWED

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            reservedPercent: 0,
            cashOutTaxRate: JBConstants.MAX_CASH_OUT_TAX_RATE,
            weightCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            // not allowed
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

        vm.expectRevert(JBTerminalStore.JBTerminalStore_TerminalMigrationNotAllowed.selector);
        _store.recordTerminalMigration(_projectId, address(_token));
    }
}
