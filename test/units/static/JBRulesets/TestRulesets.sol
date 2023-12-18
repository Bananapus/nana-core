// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from 'forge-std/Test.sol';

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/**
 * @title 
 */
contract TestJBRulesetsUnits_Local is Test {
    // Contracts
    JBRulesets public _rulesets;
    IJBDirectory internal _directory;
    IJBPermissions internal _permissions;

    // Necessary params
    JBRulesetMetadata private _metadata;
    uint256 _packedMetadata;

    function setUp() public {

    // Mock contracts and label them
    _directory = IJBDirectory(makeAddr("JBDirectory"));
    _permissions = IJBPermissions(makeAddr("JBPermissions"));

    // Instantiate the contract being tested
    _rulesets = new JBRulesets(_directory);

    // Params for tests
    _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
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

    _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);

    }

    function testQueueFor() public {
        // Setup: queueFor will call onlyControllerOf -> Directory to see if caller has proper permissions, mock that.
        vm.mockCall(address(_directory), abi.encodeCall(IJBDirectory.controllerOf, (1)), abi.encode(address(this)));

        // Check: Ensure calls go through
        vm.expectCall(
            address(_directory), abi.encodeCall(IJBDirectory.controllerOf, (1))
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: 1,
            duration: 14,
            weight: 0,
            decayRate: 450_000_000,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata,
            mustStartAtOrAfter: 0
        });

        // To-do: check ruleset was properly set & event (RulesetQueued) was emitted
    }

}