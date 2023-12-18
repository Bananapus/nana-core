// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Test} from 'forge-std/Test.sol';

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

// Struggling with smock in general, might just manually setup each..
import {MockJBDirectory} from '../../../mock/smock/MockJBDirectory.sol';
import {MockJBPermissions} from '../../../mock/smock/MockJBPermissions.sol';
import { SmockHelper } from '../../../mock/smock/SmockHelper.sol';

/**
 * @title 
 */
contract TestJBRulesetsUnits_Local is Test, SmockHelper {

    // 
    JBRulesets public _rulesets;
    JBRulesetMetadata private _metadata;
    uint256 _packedMetadata;
    address public _directoryAddress;
    address public _controlledAddress;
    address public _permissionsAddress;
    MockJBDirectory public _directory;
    MockJBPermissions public _permissions;

    function setUp() public {

    // deployMock is returning an address even tho docs say it should be assignable to the MockContract contract type.. 
    _permissionsAddress = deployMock(
        'JBPermissions',
        type(JBPermissions).creationCode,
        abi.encode()
    );

    IJBPermissions perms = IJBPermissions(makeAddr("perms"));
    IJBProjects projects = IJBProjects(makeAddr("projects"));

    // deployMock is returning an address even tho docs say it should be assignable to the MockContract contract type.. 
    _directoryAddress = deployMock(
        'JBDirectory',
        type(JBDirectory).creationCode,
        abi.encode(perms, projects, address(this))
    );

    // Reassignments because of the issue mentioned above
    _permissions = MockJBPermissions(_permissionsAddress);

    _directory = MockJBDirectory(_directoryAddress);

    _rulesets = new JBRulesets(IJBDirectory(_directoryAddress));

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

        // Couldn't get this to work... non-descript "EVM Error"
        /* _directory.mock_call_controllerOf(1, IERC165(address(this))); */

        vm.mockCall(address(_directory), abi.encodeCall(IJBDirectory.controllerOf, (1)), abi.encode(address(this)));

        vm.expectCall(
            address(_directory), abi.encodeCall(IJBDirectory.controllerOf, (1))
        );

        _rulesets.queueFor({
            projectId: 1,
            duration: 14,
            weight: 0,
            decayRate: 450_000_000,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: _packedMetadata,
            mustStartAtOrAfter: 0
        });
    }

}