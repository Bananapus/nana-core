// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

uint256 constant WEIGHT = 1000 * 10 ** 18;

contract TestReconfigureProject_Local is TestBaseWorkflow {
    JBController controller;
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleData _dataReconfiguration;
    JBFundingCycleData _dataWithoutBallot;
    JBFundingCycleMetadata3_2 _metadata;
    JBReconfigurationBufferBallot _ballot;
    JBGroupedSplits[] _groupedSplits; // Default empty
    JBFundAccessConstraints3_1[] _fundAccessConstraints; // Default empty
    IJBPaymentTerminal[] _terminals; // Default empty

    uint256 BALLOT_DURATION = 3 days;

    function setUp() public override {
        super.setUp();

        controller = jbController();

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _ballot = new JBReconfigurationBufferBallot(BALLOT_DURATION);

        _data = JBFundingCycleData({duration: 6 days, weight: 10000 * 10 ** 18, discountRate: 0, ballot: _ballot});

        _dataWithoutBallot = JBFundingCycleData({
            duration: 6 days,
            weight: 1000 * 10 ** 18,
            discountRate: 0,
            ballot: JBReconfigurationBufferBallot(address(0))
        });

        _dataReconfiguration = JBFundingCycleData({
            duration: 6 days,
            weight: 69 * 10 ** 18,
            discountRate: 0,
            ballot: JBReconfigurationBufferBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata3_2({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000,
            redemptionRate: 5000,
            baseCurrency: 1,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: true,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            preferClaimedTokenOverride: false,
            useTotalOverflowForRedemptions: false,
            useDataSourceForPay: false,
            useDataSourceForRedeem: false,
            dataSource: address(0),
            metadata: 0
        });

        _terminals = [jbETHPaymentTerminal()];
    }

    function testReconfigureProject() public {
        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);

        assertEq(fundingCycle.number, 1); // ok
        assertEq(fundingCycle.weight, _data.weight);

        uint256 currentConfiguration = fundingCycle.configuration;

        vm.warp(block.timestamp + 1); // Avoid overwriting if same timestamp

        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _cycleConfig,
            ""
        );

        // Shouldn't have changed
        fundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.configuration, currentConfiguration);
        assertEq(fundingCycle.weight, _data.weight);

        // should be new funding cycle
        vm.warp(fundingCycle.start + fundingCycle.duration);

        JBFundingCycle memory newFundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(newFundingCycle.number, 2);
        assertEq(newFundingCycle.weight, _data.weight);
    }

    function testMultipleReconfigurationOnRolledOver() public {
        uint256 weightFirstReconfiguration = 1234 * 10 ** 18;
        uint256 weightSecondReconfiguration = 6969 * 10 ** 18;

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);

        // Initial funding cycle data
        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.weight, _data.weight);

        uint256 currentConfiguration = fundingCycle.configuration;

        // Jump to FC+1, rolled over
        vm.warp(block.timestamp + fundingCycle.duration);

        JBFundingCycleConfiguration[] memory _firstReconfig = new JBFundingCycleConfiguration[](1);

        _firstReconfig[0].mustStartAtOrAfter = 0;
        _firstReconfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightFirstReconfiguration, discountRate: 0, ballot: _ballot}); // 3days ballot;
        _firstReconfig[0].metadata = _metadata;
        _firstReconfig[0].groupedSplits = _groupedSplits;
        _firstReconfig[0].fundAccessConstraints = _fundAccessConstraints;

        // First reconfiguration
        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _firstReconfig,
            ""
        );

        vm.warp(block.timestamp + 1); // Avoid overwrite

        JBFundingCycleConfiguration[] memory _secondReconfig = new JBFundingCycleConfiguration[](1);

        _secondReconfig[0].mustStartAtOrAfter = 0;
        _secondReconfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightSecondReconfiguration, discountRate: 0, ballot: _ballot}); // 3days ballot;
        _secondReconfig[0].metadata = _metadata;
        _secondReconfig[0].groupedSplits = _groupedSplits;
        _secondReconfig[0].fundAccessConstraints = _fundAccessConstraints;

        // Second reconfiguration (different configuration)
        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _secondReconfig,
            ""
        );
        uint256 secondReconfiguration = block.timestamp;

        // Shouldn't have changed, still in FC#2, rolled over from FC#1
        fundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(fundingCycle.number, 2);
        assertEq(fundingCycle.configuration, currentConfiguration);
        assertEq(fundingCycle.weight, _data.weight);

        // Jump to after the ballot passed, but before the next FC
        vm.warp(fundingCycle.start + fundingCycle.duration - 1);

        // Queued should be the second reconfiguration
        JBFundingCycle memory queuedFundingCycle = jbFundingCycleStore().queuedOf(projectId);
        assertEq(queuedFundingCycle.number, 3);
        assertEq(queuedFundingCycle.configuration, secondReconfiguration);
        assertEq(queuedFundingCycle.weight, weightSecondReconfiguration);

        vm.warp(fundingCycle.start + fundingCycle.duration);

        // Second reconfiguration should be now the current one
        JBFundingCycle memory newFundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(newFundingCycle.number, 3);
        assertEq(newFundingCycle.configuration, secondReconfiguration);
        assertEq(newFundingCycle.weight, weightSecondReconfiguration);
    }

    function testMultipleReconfigure(uint8 FUZZED_BALLOT_DURATION) public {
        _ballot = new JBReconfigurationBufferBallot(FUZZED_BALLOT_DURATION);

        _data = JBFundingCycleData({duration: 6 days, weight: 10000 ether, discountRate: 0, ballot: _ballot});

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory initialFundingCycle = jbFundingCycleStore().currentOf(projectId);
        JBFundingCycle memory currentFundingCycle = initialFundingCycle;
        JBFundingCycle memory queuedFundingCycle = jbFundingCycleStore().queuedOf(projectId);

        vm.warp(currentFundingCycle.start + 1); // Avoid overwriting current fc while reconfiguring

        for (uint256 i = 0; i < 4; i++) {
            currentFundingCycle = jbFundingCycleStore().currentOf(projectId);

            if (FUZZED_BALLOT_DURATION + i * 1 days < currentFundingCycle.duration) {
                assertEq(currentFundingCycle.weight, initialFundingCycle.weight - i);
            }

            _data = JBFundingCycleData({
                duration: 6 days,
                weight: initialFundingCycle.weight - (i + 1), // i+1 -> next funding cycle
                discountRate: 0,
                ballot: _ballot
            });

            JBFundingCycleConfiguration[] memory _reconfig = new JBFundingCycleConfiguration[](1);

            _reconfig[0].mustStartAtOrAfter = 0;
            _reconfig[0].data = _data;
            _reconfig[0].metadata = _metadata;
            _reconfig[0].groupedSplits = _groupedSplits;
            _reconfig[0].fundAccessConstraints = _fundAccessConstraints;

            vm.prank(multisig());
            controller.reconfigureFundingCyclesOf(
                projectId, _reconfig, ""
            );

            currentFundingCycle = jbFundingCycleStore().currentOf(projectId);
            queuedFundingCycle = jbFundingCycleStore().queuedOf(projectId);

            // Queued is the funding cycle currently under ballot
            assertEq(queuedFundingCycle.weight, _data.weight);
            assertEq(queuedFundingCycle.number, currentFundingCycle.number + 1);

            // Is the full ballot duration included in the funding cycle?
            if (
                FUZZED_BALLOT_DURATION == 0
                    || currentFundingCycle.duration % (FUZZED_BALLOT_DURATION + i * 1 days) < currentFundingCycle.duration
            ) {
                assertEq(currentFundingCycle.weight, initialFundingCycle.weight - i);

                uint256 _previousFundingCycleNumber = currentFundingCycle.number;

                // we shift forward the start of the ballot into the fc, one day at a time, from fc to fc
                vm.warp(currentFundingCycle.start + currentFundingCycle.duration + i * 1 days);

                // Ballot was Approved and we've changed fc, current is the reconfiguration
                currentFundingCycle = jbFundingCycleStore().currentOf(projectId);
                assertEq(currentFundingCycle.weight, _data.weight);
                assertEq(currentFundingCycle.number, _previousFundingCycleNumber + 1);

                // Queued is the reconfiguration rolled-over
                queuedFundingCycle = jbFundingCycleStore().queuedOf(projectId);
                assertEq(queuedFundingCycle.weight, _data.weight);
                assertEq(queuedFundingCycle.number, currentFundingCycle.number + 1);
            }
            // the ballot is accross two funding cycles
            else {
                // Warp to begining of next FC: should be the previous fc config rolled over (ballot is in Failed state)
                vm.warp(currentFundingCycle.start + currentFundingCycle.duration);
                assertEq(currentFundingCycle.weight, initialFundingCycle.weight - i);
                uint256 cycleNumber = currentFundingCycle.number;

                // Warp to after the end of the ballot, within the same fc: should be the new fc (ballot is in Approved state)
                vm.warp(currentFundingCycle.start + currentFundingCycle.duration + FUZZED_BALLOT_DURATION);
                currentFundingCycle = jbFundingCycleStore().currentOf(projectId);
                assertEq(currentFundingCycle.weight, _data.weight);
                assertEq(currentFundingCycle.number, cycleNumber + 1);
            }
        }
    }

    function testLaunchProjectWrongBallot() public {
        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycleData memory _dataNew = JBFundingCycleData({
            duration: 6 days,
            weight: 12345 * 10 ** 18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(6969)) // Wrong ballot address
        });

        vm.warp(block.timestamp + 1); // Avoid overwriting if same timestamp

        vm.prank(multisig());
        vm.expectRevert(abi.encodeWithSignature("INVALID_BALLOT()"));

        JBFundingCycleConfiguration[] memory _reconfig = new JBFundingCycleConfiguration[](1);

        _reconfig[0].mustStartAtOrAfter = 0;
        _reconfig[0].data = _dataNew;
        _reconfig[0].metadata = _metadata;
        _reconfig[0].groupedSplits = _groupedSplits;
        _reconfig[0].fundAccessConstraints = _fundAccessConstraints;

        controller.reconfigureFundingCyclesOf(
            projectId,
            _reconfig,
            ""
        );
    }

    function testReconfigureShortDurationProject() public {
        _data = JBFundingCycleData({duration: 5 minutes, weight: 10000 * 10 ** 18, discountRate: 0, ballot: _ballot});

        _dataReconfiguration = JBFundingCycleData({
            duration: 6 days,
            weight: 69 * 10 ** 18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);

        assertEq(fundingCycle.number, 1); // ok
        assertEq(fundingCycle.weight, _data.weight);

        uint256 currentConfiguration = fundingCycle.configuration;

        vm.warp(block.timestamp + 1); // Avoid overwriting if same timestamp

        JBFundingCycleConfiguration[] memory _reconfig = new JBFundingCycleConfiguration[](1);

        _reconfig[0].mustStartAtOrAfter = 0;
        _reconfig[0].data = _dataReconfiguration;
        _reconfig[0].metadata = _metadata;
        _reconfig[0].groupedSplits = _groupedSplits;
        _reconfig[0].fundAccessConstraints = _fundAccessConstraints;

        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _reconfig,
            ""
        );

        // Shouldn't have changed (same cycle, with a ballot)
        fundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.configuration, currentConfiguration);
        assertEq(fundingCycle.weight, _data.weight);

        // shouldn't have changed (new cycle but ballot is still active)
        vm.warp(fundingCycle.start + fundingCycle.duration);

        JBFundingCycle memory newFundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(newFundingCycle.number, 2);
        assertEq(newFundingCycle.weight, _data.weight);

        // should now be the reconfiguration (ballot duration is over)
        vm.warp(fundingCycle.start + fundingCycle.duration + 3 days);

        newFundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(newFundingCycle.number, fundingCycle.number + (3 days / 5 minutes) + 1);
        assertEq(newFundingCycle.weight, _dataReconfiguration.weight);
    }

    function testReconfigureWithoutBallot() public {
        _data = JBFundingCycleData({
            duration: 5 minutes,
            weight: 10000 * 10 ** 18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        _dataReconfiguration = JBFundingCycleData({
            duration: 6 days,
            weight: 69 * 10 ** 18,
            discountRate: 0,
            ballot: IJBFundingCycleBallot(address(0))
        });

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);

        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.weight, _data.weight);

        vm.warp(block.timestamp + 10); // Avoid overwriting if same timestamp

        JBFundingCycleConfiguration[] memory _reconfig = new JBFundingCycleConfiguration[](1);

        _reconfig[0].mustStartAtOrAfter = 0;
        _reconfig[0].data = _dataReconfiguration;
        _reconfig[0].metadata = _metadata;
        _reconfig[0].groupedSplits = _groupedSplits;
        _reconfig[0].fundAccessConstraints = _fundAccessConstraints;

        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _reconfig,
            ""
        );
        // Should not have changed
        fundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.weight, _data.weight);

        // Should have changed after the current funding cycle is over
        vm.warp(fundingCycle.start + fundingCycle.duration);
        fundingCycle = jbFundingCycleStore().currentOf(projectId);
        assertEq(fundingCycle.number, 2);
        assertEq(fundingCycle.weight, _dataReconfiguration.weight);
    }

    function testMixedStarts() public {
        // Keep references to our different weights for assertions
        uint256 weightInitial = 1000 * 10 ** 18;
        uint256 weightFirstReconfiguration = 1234 * 10 ** 18;
        uint256 weightSecondReconfiguration = 6969 * 10 ** 18;

        // Keep a reference to the expected configuration timestamps
        uint256 initialTimestamp = block.timestamp;
        uint256 expectedTimestamp = block.timestamp;

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightInitial, discountRate: 0, ballot: JBReconfigurationBufferBallot(_ballot)}); // 3days ballot;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);

        // First cycle has begun
        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.weight, weightInitial);
        assertEq(fundingCycle.configuration, block.timestamp);

        JBFundingCycleConfiguration[] memory _firstReconfig = new JBFundingCycleConfiguration[](1);

        _firstReconfig[0].mustStartAtOrAfter = 0;
        _firstReconfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightFirstReconfiguration, discountRate: 0, ballot: JBReconfigurationBufferBallot(_ballot)}); // 3days ballot;
        _firstReconfig[0].metadata = _metadata;
        _firstReconfig[0].groupedSplits = _groupedSplits;
        _firstReconfig[0].fundAccessConstraints = _fundAccessConstraints;

        // create a to-be overridden reconfiguration (will be in ApprovalExpected status due to ballot)
        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _firstReconfig,
            ""
        );

        // Confirm the configuration is queued
        expectedTimestamp += 1;
        JBFundingCycle memory queued = jbFundingCycleStore().queuedOf(projectId);

        assertEq(queued.number, 2);
        assertEq(queued.configuration, expectedTimestamp);
        assertEq(queued.weight, weightFirstReconfiguration);

        JBFundingCycleConfiguration[] memory _secondReconfig = new JBFundingCycleConfiguration[](1);

        _secondReconfig[0].mustStartAtOrAfter = block.timestamp + 9 days;
        _secondReconfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightSecondReconfiguration, discountRate: 0, ballot: JBReconfigurationBufferBallot(_ballot)}); // 3days ballot;
        _secondReconfig[0].metadata = _metadata;
        _secondReconfig[0].groupedSplits = _groupedSplits;
        _secondReconfig[0].fundAccessConstraints = _fundAccessConstraints;

        // Will follow the rolledover (FC #1) cycle, after overriding the above config, bc first reconfig is in ApprovalExpected status (3 days ballot has not passed)
        // FC #1 rolls over bc our mustStartAtOrAfter occurs later than when FC #1 ends.
        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _secondReconfig,
            ""
        );

        // Confirm that this latest reconfiguration implies a rolled over cycle of FC #1.
        expectedTimestamp += 1;
        JBFundingCycle memory requeued = jbFundingCycleStore().queuedOf(projectId);

        assertEq(requeued.number, 2);
        assertEq(requeued.configuration, initialTimestamp);
        assertEq(requeued.weight, weightInitial);

        // Warp to when the initial configuration rolls over and again becomes the current
        vm.warp(block.timestamp + 6 days);

        // Rolled over configuration
        JBFundingCycle memory initialIsCurrent = jbFundingCycleStore().currentOf(projectId);
        assertEq(initialIsCurrent.number, 2);
        assertEq(initialIsCurrent.configuration, initialTimestamp);
        assertEq(initialIsCurrent.weight, weightInitial);

        // Queued second reconfiguration that replaced our first reconfiguration
        JBFundingCycle memory requeued2 = jbFundingCycleStore().queuedOf(projectId);
        assertEq(requeued2.number, 3);
        assertEq(requeued2.configuration, expectedTimestamp);
        assertEq(requeued2.weight, weightSecondReconfiguration);
    }

    function testSingleBlockOverwriteQueued() public {
        uint256 weightFirstReconfiguration = 1234 * 10 ** 18;
        uint256 weightSecondReconfiguration = 6969 * 10 ** 18;

        // Keep a reference to the expected timestamp after reconfigurations, starting now, incremented later in-line for readability.
        uint256 expectedTimestamp = block.timestamp;

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = controller.launchProjectFor(
            multisig(),
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId);

        // Initial funding cycle data: will have a block.timestamp (configuration) that is 2 less than the second reconfiguration (timestamps are incremented when queued in same block now)
        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.weight, _data.weight);

        JBFundingCycleConfiguration[] memory _firstReconfig = new JBFundingCycleConfiguration[](1);

        _firstReconfig[0].mustStartAtOrAfter = block.timestamp + 3 days;
        _firstReconfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightFirstReconfiguration, discountRate: 0, ballot: JBReconfigurationBufferBallot(_ballot)}); // 3days ballot;
        _firstReconfig[0].metadata = _metadata;
        _firstReconfig[0].groupedSplits = _groupedSplits;
        _firstReconfig[0].fundAccessConstraints = _fundAccessConstraints;

        // Becomes queued & will be overwritten as 3 days will not pass and it's status is "ApprovalExpected"
        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _firstReconfig,
            ""
        );

        expectedTimestamp += 1;

        JBFundingCycle memory queuedToOverwrite = jbFundingCycleStore().queuedOf(projectId);

        assertEq(queuedToOverwrite.number, 2);
        assertEq(queuedToOverwrite.configuration, expectedTimestamp);
        assertEq(queuedToOverwrite.weight, weightFirstReconfiguration);

        JBFundingCycleConfiguration[] memory _secondReconfig = new JBFundingCycleConfiguration[](1);

        _secondReconfig[0].mustStartAtOrAfter = block.timestamp + 3 days;
        _secondReconfig[0].data = JBFundingCycleData({duration: 6 days, weight: weightSecondReconfiguration, discountRate: 0, ballot: JBReconfigurationBufferBallot(_ballot)}); // 3days ballot;
        _secondReconfig[0].metadata = _metadata;
        _secondReconfig[0].groupedSplits = _groupedSplits;
        _secondReconfig[0].fundAccessConstraints = _fundAccessConstraints;

        // overwriting reconfiguration
        vm.prank(multisig());
        controller.reconfigureFundingCyclesOf(
            projectId,
            _secondReconfig,
            ""
        );

        expectedTimestamp += 1;

        JBFundingCycle memory queued = jbFundingCycleStore().queuedOf(projectId);

        assertEq(queued.number, 2);
        assertEq(queued.configuration, expectedTimestamp);
        assertEq(queued.weight, weightSecondReconfiguration);

    }
}
