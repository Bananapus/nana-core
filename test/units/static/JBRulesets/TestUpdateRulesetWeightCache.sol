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
    uint256 _mustStartAt = 0;
    uint256 _hookDuration = 1 days;

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

    function test_WhenLatestRulesetOfProjectDurationOrDecayRateEQZero() external {
        // it will return without updating
    }

    function test_WhenLatestRulesetHasProperDurationAndDecayRate() external {
        // it will store a new derivedWeightFrom and decayMultiple in storage
    }
}
