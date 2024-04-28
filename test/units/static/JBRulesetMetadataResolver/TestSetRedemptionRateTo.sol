// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

contract TestSetRedemptionRateTo_Local is JBTest {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    function setUp() external {}

    function testEnsureCorrectlyPacked() external {
        // redemption rate should be re-set and re-packed correctly

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, // 5000
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            allowControllerMigration: false,
            allowSetController: false,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        // Package up the ruleset configuration.
        JBRulesetConfig[] memory _rulesetConfigurations = new JBRulesetConfig[](1);
        _rulesetConfigurations[0].mustStartAtOrAfter = 0;
        _rulesetConfigurations[0].duration = 0;
        _rulesetConfigurations[0].weight = 1e18;
        _rulesetConfigurations[0].decayRate = 0;
        _rulesetConfigurations[0].approvalHook = IJBRulesetApprovalHook(address(0));
        _rulesetConfigurations[0].metadata = _rulesMetadata;

        // JBRulesets calldata
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: _rulesetConfigurations[0].duration,
            weight: _rulesetConfigurations[0].weight,
            decayRate: _rulesetConfigurations[0].decayRate,
            approvalHook: _rulesetConfigurations[0].approvalHook,
            metadata: _packed
        });

        JBRuleset memory _repacked = JBRulesetMetadataResolver.setRedemptionRateTo(ruleset, 1000);

        uint256 _rate = uint256(uint16(_repacked.metadata >> 20));
        assertEq(_rate, 1000);
    }

    function testEnsureCorrectlyPackedBits72And74() external {
        // redemption rate should be re-set and re-packed correctly

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedRate: JBConstants.MAX_RESERVED_RATE / 2,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE / 2, // 5000
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: false,
            allowTerminalMigration: false,
            allowSetTerminals: true, // testing this
            allowControllerMigration: false,
            allowSetController: true,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        uint256 _allowSetTerminals = uint256(uint16(_packed >> 72) & 1);
        uint256 _allowSetController = uint256(uint16(_packed >> 74) & 1);
        assertEq(_allowSetTerminals, 1);
        assertEq(_allowSetController, 1);
    }
}
