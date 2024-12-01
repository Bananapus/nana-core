// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestUpcomingOf_Local is JBRulesetsSetup {
    // Necessary params
    JBRulesetMetadata private _metadata;
    JBRulesetMetadata private _metadataWithApprovalHook;
    IJBRulesetApprovalHook private _mockApprovalHook = IJBRulesetApprovalHook(makeAddr("hook"));
    uint256 _packedMetadata;
    uint256 _packedWithApprovalHook;
    uint256 _projectId = 1;
    uint256 _duration = 3 days;
    uint256 _weight = 0;
    uint256 _weightCutPercent = 450_000_000;
    uint48 _mustStartAt = 0;
    uint256 _hookDuration = 1 days;
    IJBRulesetApprovalHook private _noHook = IJBRulesetApprovalHook(address(0));

    function setUp() public {
        super.rulesetsSetup();

        // Params for tests
        _metadata = JBRulesetMetadata({
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

        // Params for tests
        _metadataWithApprovalHook = JBRulesetMetadata({
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

        _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);
        _packedWithApprovalHook = JBRulesetMetadataResolver.packRulesetMetadata(_metadataWithApprovalHook);
    }

    function test_WhenLatestRulesetIdEQZero() external {
        // it will return an empty ruleset

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, 0);
    }

    modifier whenUpcomingRulesetIdDNEQZero() {
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

        // mock call to hook duration
        mockExpect(
            address(_mockApprovalHook), abi.encodeCall(IJBRulesetApprovalHook.DURATION, ()), abi.encode(_hookDuration)
        );

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp,
            _projectId,
            _duration,
            _weight,
            _weightCutPercent,
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
            weightCutPercent: _weightCutPercent,
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
            _weightCutPercent,
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
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });
        _;
    }

    function test_GivenStatusEQApprovedOrApprovalExpectedOrEmpty() external whenUpcomingRulesetIdDNEQZero {
        // it will return that ruleset

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + _duration)
            ),
            abi.encode(JBApprovalStatus.ApprovalExpected)
        );

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, block.timestamp + 1); // timestamp + 1 = second queued, since the preceeding ruleset is
            // in
    }

    function test_GivenStatusDNEQApprovedOrApprovalExpectedOrEmpty() external whenUpcomingRulesetIdDNEQZero {
        // it will return the ruleset upcoming was based on

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + _duration)
            ),
            abi.encode(JBApprovalStatus.Active)
        );

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, block.timestamp); // first queued, since the preceeding ruleset approval hook is still
            // "Active"
    }

    function test_GivenTheLatestRulesetStartsInTheFuture() external {
        // it will return the ruleset that latestRuleset is based on, which is zero in this case, which defaults to an
        // approval status of "Empty"

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
            _weightCutPercent,
            _mockApprovalHook,
            _packedWithApprovalHook,
            block.timestamp + 10 days, // starts in the future
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: uint48(block.timestamp + 10 days)
        });

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, block.timestamp);
    }

    function test_WhenLatestRulesetHasDurationEqZero() external {
        // it will return an empty ruleset

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
            0, // duration zero
            _weight,
            _weightCutPercent,
            _mockApprovalHook,
            _packedWithApprovalHook,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: 0,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        // mock call to hook duration
        mockExpect(
            address(_mockApprovalHook), abi.encodeCall(IJBRulesetApprovalHook.DURATION, ()), abi.encode(_hookDuration)
        );

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp + 1, // incremented by one since queued in the same block and we cant have duplicate ids
            _projectId,
            0, // duration zero
            _weight,
            _weightCutPercent,
            _mockApprovalHook,
            _packedWithApprovalHook,
            block.timestamp + 10 days,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: 0,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: uint48(block.timestamp + 10 days)
        });

        vm.warp(block.timestamp + 11 days);

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, 0);
    }

    function test_GivenApprovalStatusIsApprovedOrEmpty() external whenUpcomingRulesetIdDNEQZero {
        // it will return a simulatedCycledRulesetBasedOn

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + _duration)
            ),
            abi.encode(JBApprovalStatus.Approved)
        );

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, block.timestamp + 1); // timestamp + 1 = second queued
    }

    function test_GivenTheRulesetsApprovalFailedAndItsBasedOnDurationDNEQZero()
        external
        whenUpcomingRulesetIdDNEQZero
    {
        // it will return the simulatedCycledRulesetBasedOn it was based on

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + _duration)
            ),
            abi.encode(JBApprovalStatus.Failed)
        );

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, block.timestamp); // first timestamp = first queued
    }

    // duplicate covered above in a single case
    function test_GivenTheRulesetsApprovalFailedAndItsBasedOnDurationEQZero() external {
        // it will return an empty ruleset

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
            0, // duration zero
            _weight,
            _weightCutPercent,
            _mockApprovalHook,
            _packedWithApprovalHook,
            block.timestamp,
            address(this)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: 0,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        // mock call to hook duration
        mockExpect(
            address(_mockApprovalHook), abi.encodeCall(IJBRulesetApprovalHook.DURATION, ()), abi.encode(_hookDuration)
        );

        // Setup: expect ruleset event (RulesetQueued) is emitted
        vm.expectEmit();
        emit IJBRulesets.RulesetQueued(
            block.timestamp + 1, // incremented by one since queued in the same block and we cant have duplicate ids
            _projectId,
            _duration,
            _weight,
            _weightCutPercent,
            _mockApprovalHook,
            _packedWithApprovalHook,
            block.timestamp + 10 days,
            address(this)
        );

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(
                IJBRulesetApprovalHook.approvalStatusOf, (_projectId, block.timestamp + 1, block.timestamp + 10 days)
            ),
            abi.encode(JBApprovalStatus.ApprovalExpected)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: uint48(block.timestamp + 10 days)
        });

        vm.warp(block.timestamp + 11 days);

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, 0);
    }

    // Not sure how to reach the last line of this function..
    function test_baseRulesetDurationDNEQZero() external {
        // it will simulate a ruleset basedOn

        uint256 ogTimestamp = block.timestamp;

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
            _weightCutPercent,
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
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: _mustStartAt
        });

        // mock call to hook duration
        mockExpect(
            address(_mockApprovalHook), abi.encodeCall(IJBRulesetApprovalHook.DURATION, ()), abi.encode(_hookDuration)
        );

        // Send: Call from this contract as it's been mock authorized above.
        _rulesets.queueFor({
            projectId: _projectId,
            duration: _duration,
            weight: _weight,
            weightCutPercent: _weightCutPercent,
            approvalHook: _mockApprovalHook,
            metadata: _packedWithApprovalHook,
            mustStartAtOrAfter: 0
        });

        vm.warp(block.timestamp + 3 days);

        // mock call to hook approvalStatusOf
        mockExpect(
            address(_mockApprovalHook),
            abi.encodeCall(IJBRulesetApprovalHook.approvalStatusOf, (_projectId, ogTimestamp + 1, ogTimestamp + 3 days)),
            abi.encode(JBApprovalStatus.Failed)
        );

        JBRuleset memory _upcoming = _rulesets.upcomingOf(_projectId);
        assertEq(_upcoming.id, ogTimestamp); // original id
    }
}
