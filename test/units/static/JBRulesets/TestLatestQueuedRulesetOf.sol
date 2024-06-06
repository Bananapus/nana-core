// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestLatestQueuedRulesetOf_Local is JBRulesetsSetup {
    // Necessary params
    JBRulesetMetadata private _metadata;
    JBRulesetMetadata private _metadataWithApprovalHook;
    IJBRulesetApprovalHook private _mockApprovalHook = IJBRulesetApprovalHook(makeAddr("hook"));
    uint256 _packedMetadata;
    uint256 _packedWithApprovalHook;
    uint256 _projectId = 1;
    uint256 _duration = 3 days;
    uint256 _weight = 0;
    uint256 _decayRate = 450_000_000;
    uint256 _mustStartAt = 0;
    uint256 _hookDuration = 1 days;
    IJBRulesetApprovalHook private _noHook = IJBRulesetApprovalHook(address(0));

    function setUp() public {
        super.rulesetsSetup();

        // Params for tests
        _metadata = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
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

        // Params for tests
        _metadataWithApprovalHook = JBRulesetMetadata({
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
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

        _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);
        _packedWithApprovalHook = JBRulesetMetadataResolver.packRulesetMetadata(_metadataWithApprovalHook);
    }

    modifier whenTheLatestRulesetIdDneqZero() {
        // put code at hook address
        vm.etch(address(_mockApprovalHook), abi.encode(1));

        // mock call to hook interface support
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBRulesetApprovalHook).interfaceId)),
            abi.encode(true)
        );

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(directory), _encodedCall, _willReturn);

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp,
            _projectId,
            _duration,
            _weight,
            _decayRate,
            _mockApprovalHook,
            _packedWithApprovalHook,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        _;
    }

    function test_GivenTheRulesetIsBasedOnRulesetZero() external whenTheLatestRulesetIdDneqZero {
        // it will return JBApprovalStatus.Empty

        (JBRuleset memory _latestRuleset, JBApprovalStatus _latestApprovalStatus) = _rulesets.latestQueuedOf(_projectId);
        assertEq(uint256(_latestApprovalStatus), 0);
        assertEq(_latestRuleset.id, block.timestamp);
    }

    function test_GivenTheRulesetIsBasedOnNonzeroRulesetAndTheBasedOnApprovalhookDneqZeroAddress()
        external
        whenTheLatestRulesetIdDneqZero
    {
        // it will return the approvalHooks approvalStatusOf

        // mock call to hook duration
        mockExpect(
            address(_mockApprovalHook), abi.encodeCall(IJBRulesetApprovalHook.DURATION, ()), abi.encode(_hookDuration)
        );

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp + 1, // queued after the first in the modifier
            _projectId,
            _duration,
            _weight,
            _decayRate,
            _noHook,
            _packedMetadata,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _noHook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + _duration)
            ),
            abi.encode(JBApprovalStatus.ApprovalExpected)
        );

        (JBRuleset memory _latestRuleset, JBApprovalStatus _latestApprovalStatus) = _rulesets.latestQueuedOf(_projectId);
        assertEq(uint256(_latestApprovalStatus), 3); // 3 = enum ApprovalExpected of the basedOn ruleset
        assertEq(_latestRuleset.id, block.timestamp + 1); // second queued ruleset
    }

    function test_GivenTheRulesetIsBasedOnNonzeroRulesetAndTheBasedOnApprovalhookEqZeroAddress() external {
        // it will return JBApprovalStatus.Empty

        // Setup: queueFor will call onlyControllerOf modifier -> Directory.controllerOf to see if caller has proper
        // permissions, encode & mock that.
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(directory), _encodedCall, _willReturn);

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp, // queued after the first in the modifier
            _projectId,
            _duration,
            _weight,
            _decayRate,
            _noHook,
            _packedMetadata,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _noHook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp + 1, // queued after the first in the modifier
            _projectId,
            _duration,
            _weight,
            _decayRate,
            _noHook,
            _packedMetadata,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            decayRate: _decayRate,
            approvalHook: _noHook,
            metadata: _packedMetadata,
            mustStartAtOrAfter: _mustStartAt
        });

        (JBRuleset memory _latestRuleset, JBApprovalStatus _latestApprovalStatus) = _rulesets.latestQueuedOf(_projectId);
        assertEq(uint256(_latestApprovalStatus), 0); // 0 = enum Empty of the basedOn ruleset
        assertEq(_latestRuleset.id, block.timestamp + 1); // second queued ruleset
    }

    function test_WhenTheLatestRulesetIdEqZero() external {
        // it will return empty ruleset and JBApprovalStatus.Empty

        (JBRuleset memory _latestRuleset, JBApprovalStatus _latestApprovalStatus) = _rulesets.latestQueuedOf(_projectId);
        assertEq(uint256(_latestApprovalStatus), 0); // 0 = enum Empty of the basedOn ruleset
        assertEq(_latestRuleset.id, 0); // second queued ruleset
    }
}
