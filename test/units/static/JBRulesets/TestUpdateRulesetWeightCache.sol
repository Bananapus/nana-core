// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBRulesetsSetup} from "./JBRulesetsSetup.sol";

contract TestUpdateRulesetWeightCache_Local is JBRulesetsSetup {
    // Necessary params
    JBRulesetMetadata private _metadata;
    uint256 _packedMetadata;
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

        _packedMetadata = JBRulesetMetadataResolver.packRulesetMetadata(_metadata);
    }

    function test_WhenLatestRulesetOfProjectDurationOrDecayRateEQZero() external {
        // it will return without updating

        _rulesets.updateRulesetWeightCache(_projectId);
    }

    function test_WhenLatestRulesetHasProperDurationAndDecayRate() external {
        // it will store a new derivedWeightFrom and decayMultiple in storage

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

        _rulesets.updateRulesetWeightCache(_projectId);
    }
}
