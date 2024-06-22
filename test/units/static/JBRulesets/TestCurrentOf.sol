// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestCurrentOf_Local is JBRulesetsSetup {
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
    uint48 _mustStartAt = 0;
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

    function test_WhenLatestrulesetOfProjectEQZero() external {
        // it will return an empty ruleset

        JBRuleset memory _ruleset = _rulesets.currentOf(_projectId);
        assertEq(_ruleset.id, 0);
    }

    modifier whenLatestRulesetIdDNEQZero() {
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

        // First queue a base funding cycle

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

        // mock call to hook duration
        mockExpect(
            address(_mockApprovalHook), abi.encodeCall(IJBRulesetApprovalHook.DURATION, ()), abi.encode(_hookDuration)
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

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp + 1,
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

        /* // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
        IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + _duration)
            ),
            abi.encode(JBApprovalStatus.Failed)
        ); */

        _;
    }

    function test_GivenTheCurrentlyApprovableRulesetIdOfApprovalStatusEQApprovedOrEmpty()
        external
        whenLatestRulesetIdDNEQZero
    {
        // it will return the latest approved ruleset

        JBRuleset memory _current = _rulesets.currentOf(_projectId);
        assertEq(_current.id, block.timestamp);
    }

    function test_GivenTheCurrentlyApprovableRulesetIdOfApprovalStatusDNEQApprovedOrEmpty()
        external
        whenLatestRulesetIdDNEQZero
    {
        // it will return the ruleset the pending approval ruleset is basedOn

        uint256 _firstRulesetId = block.timestamp;
        uint256 _rulesetWithHookId = block.timestamp + 1;

        vm.warp(block.timestamp + 3 days);

        // mock approvalStatusOf to return Pending
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, _rulesetWithHookId, _firstRulesetId + _duration)
            ),
            abi.encode(JBApprovalStatus.Active)
        );

        JBRuleset memory _current = _rulesets.currentOf(_projectId);
        assertEq(_current.id, _firstRulesetId);
    }

    function test_GivenTheCurrentlyApprovableRulesetIdOfEQZeroAndApprovalStatusOfTheLatestRulesetDNEQApprovedOrEmpty()
        external
        whenLatestRulesetIdDNEQZero
    {
        // it will return the basedOn of the latest ruleset

        uint256 _firstRulesetId = block.timestamp;
        uint256 _rulesetWithHookId = block.timestamp + 1;

        vm.warp(block.timestamp + 4 days);

        // mock approvalStatusOf to return Pending
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, _rulesetWithHookId, _firstRulesetId + _duration)
            ),
            abi.encode(JBApprovalStatus.Active)
        );

        JBRuleset memory _current = _rulesets.currentOf(_projectId);
        assertEq(_current.id, _firstRulesetId);
    }

    // covered above - tree had typo
    /* function test_WhenBaseOfTheCurrentlyApprovableRulesetIdOfDurationDNEQZero() external {
        // it will return simulateCycledRulesetBasedOn with allowMidRuleset true
    } */
}
