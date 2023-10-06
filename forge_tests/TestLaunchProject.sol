// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestLaunchProject_Local is TestBaseWorkflow {
    JBProjectMetadata _projectMetadata;
    JBFundingCycleData _data;
    JBFundingCycleMetadata _metadata;
    JBGroupedSplits[] _groupedSplits; // Default empty
    JBFundAccessConstraints[] _fundAccessConstraints; // Default empty
    IJBPaymentTerminal[] _terminals; // Default empty

    function setUp() public override {
        super.setUp();

        _projectMetadata = JBProjectMetadata({content: "myIPFSHash", domain: 1});

        _data = JBFundingCycleData({
            duration: 14,
            weight: 1000 * 10 ** 18,
            discountRate: 450000000,
            ballot: IJBFundingCycleBallot(address(0))
        });

        _metadata = JBFundingCycleMetadata({
            global: JBGlobalFundingCycleMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 5000, //50%
            redemptionRate: 5000, //50%
            ballotRedemptionRate: 0,
            pausePay: false,
            pauseDistributions: false,
            pauseRedeem: false,
            pauseBurn: false,
            allowMinting: false,
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
    }

    function testLaunchProject() public {
        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        uint256 projectId = jbController().launchProjectFor(
            msg.sender,
            _projectMetadata,
            _cycleConfig,
            _terminals,
            ""
        );

        JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId); //, latestConfig);

        assertEq(fundingCycle.number, 1);
        assertEq(fundingCycle.weight, 1000 * 10 ** 18);
    }

    function testLaunchProjectFuzzWeight(uint256 WEIGHT) public {
        _data = JBFundingCycleData({
            duration: 14,
            weight: WEIGHT,
            discountRate: 450000000,
            ballot: IJBFundingCycleBallot(address(0))
        });

        uint256 projectId;

        JBFundingCycleConfiguration[] memory _cycleConfig = new JBFundingCycleConfiguration[](1);

        _cycleConfig[0].mustStartAtOrAfter = 0;
        _cycleConfig[0].data = _data;
        _cycleConfig[0].metadata = _metadata;
        _cycleConfig[0].groupedSplits = _groupedSplits;
        _cycleConfig[0].fundAccessConstraints = _fundAccessConstraints;

        // expectRevert on the next call if weight overflowing
        if (WEIGHT > type(uint88).max) {
            vm.expectRevert(abi.encodeWithSignature("INVALID_WEIGHT()"));

            projectId = jbController().launchProjectFor(
                msg.sender,
                _projectMetadata,
                _cycleConfig,
                _terminals,
                ""
            );
        } else {
            projectId = jbController().launchProjectFor(
                msg.sender,
                _projectMetadata,
                _cycleConfig,
                _terminals,
                ""
            );

            JBFundingCycle memory fundingCycle = jbFundingCycleStore().currentOf(projectId); //, latestConfig);

            assertEq(fundingCycle.number, 1);
            assertEq(fundingCycle.weight, WEIGHT);
        }
    }
}
