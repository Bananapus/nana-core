// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBRulesetMetadata} from "./../structs/JBRulesetMetadata.sol";
import {JBConstants} from "./JBConstants.sol";

library JBRulesetMetadataResolver {
    function reservedRate(JBRuleset memory ruleset) internal pure returns (uint256) {
        return uint256(uint16(ruleset.metadata >> 4));
    }

    function redemptionRate(JBRuleset memory ruleset) internal pure returns (uint256) {
        // Redemption rate is a number 0-10000.
        return uint256(uint16(ruleset.metadata >> 20));
    }

    function baseCurrency(JBRuleset memory ruleset) internal pure returns (uint256) {
        // Currency is a number 0-4294967296.
        return uint256(uint32(ruleset.metadata >> 36));
    }

    function pausePay(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 68) & 1) == 1;
    }

    function pauseCreditTransfers(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 69) & 1) == 1;
    }

    function allowOwnerMinting(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 70) & 1) == 1;
    }

    function allowTerminalMigration(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 71) & 1) == 1;
    }

    function allowSetTerminals(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 72) & 1) == 1;
    }

    function allowControllerMigration(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 73) & 1) == 1;
    }

    function allowSetController(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 74) & 1) == 1;
    }

    function holdFees(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 75) & 1) == 1;
    }

    function useTotalSurplusForRedemptions(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 76) & 1) == 1;
    }

    function useDataHookForPay(JBRuleset memory ruleset) internal pure returns (bool) {
        return (ruleset.metadata >> 77) & 1 == 1;
    }

    function useDataHookForRedeem(JBRuleset memory ruleset) internal pure returns (bool) {
        return (ruleset.metadata >> 78) & 1 == 1;
    }

    function dataHook(JBRuleset memory ruleset) internal pure returns (address) {
        return address(uint160(ruleset.metadata >> 79));
    }

    function metadata(JBRuleset memory ruleset) internal pure returns (uint256) {
        return uint256(uint16(ruleset.metadata >> 239));
    }

    /// @notice Pack the funding cycle metadata.
    /// @param rulesetMetadata The ruleset metadata to validate and pack.
    /// @return packed The packed uint256 of all metadata params. The first 8 bits specify the version.
    function packRulesetMetadata(JBRulesetMetadata memory rulesetMetadata) internal pure returns (uint256 packed) {
        // version 1 in the bits 0-3 (4 bits).
        packed = 1;
        // reserved rate in bits 4-19 (16 bits).
        packed |= rulesetMetadata.reservedRate << 4;
        // redemption rate in bits 20-35 (16 bits).
        // redemption rate is a number 0-10000.
        packed |= rulesetMetadata.redemptionRate << 20;
        // base currency in bits 36-67 (32 bits).
        // base currency is a number 0-16777215.
        packed |= rulesetMetadata.baseCurrency << 36;
        // pause pay in bit 68.
        if (rulesetMetadata.pausePay) packed |= 1 << 68;
        // pause credit transfers in bit 69.
        if (rulesetMetadata.pauseCreditTransfers) packed |= 1 << 69;
        // allow discretionary minting in bit 70.
        if (rulesetMetadata.allowOwnerMinting) packed |= 1 << 70;
        // allow terminal migration in bit 71.
        if (rulesetMetadata.allowTerminalMigration) packed |= 1 << 71;
        // allow set terminals in bit 72.
        if (rulesetMetadata.allowSetTerminals) packed |= 1 << 72;
        // allow controller migration in bit 73.
        if (rulesetMetadata.allowControllerMigration) packed |= 1 << 73;
        // allow set controller in bit 74.
        if (rulesetMetadata.allowSetController) packed |= 1 << 74;
        // hold fees in bit 75.
        if (rulesetMetadata.holdFees) packed |= 1 << 75;
        // useTotalSurplusForRedemptions in bit 76.
        if (rulesetMetadata.useTotalSurplusForRedemptions) packed |= 1 << 76;
        // use pay data source in bit 77.
        if (rulesetMetadata.useDataHookForPay) packed |= 1 << 77;
        // use redeem data source in bit 78.
        if (rulesetMetadata.useDataHookForRedeem) packed |= 1 << 78;
        // data source address in bits 79-238.
        packed |= uint256(uint160(address(rulesetMetadata.dataHook))) << 79;
        // metadata in bits 239-254 (16 bits).
        packed |= rulesetMetadata.metadata << 239;
    }

    /// @notice Expand the funding cycle metadata.
    /// @param ruleset The funding cycle having its metadata expanded.
    /// @return rulesetMetadata The ruleset's metadata object.
    function expandMetadata(JBRuleset memory ruleset) internal pure returns (JBRulesetMetadata memory) {
        return JBRulesetMetadata(
            reservedRate(ruleset),
            redemptionRate(ruleset),
            baseCurrency(ruleset),
            pausePay(ruleset),
            pauseCreditTransfers(ruleset),
            allowOwnerMinting(ruleset),
            allowTerminalMigration(ruleset),
            allowSetTerminals(ruleset),
            allowControllerMigration(ruleset),
            allowSetController(ruleset),
            holdFees(ruleset),
            useTotalSurplusForRedemptions(ruleset),
            useDataHookForPay(ruleset),
            useDataHookForRedeem(ruleset),
            dataHook(ruleset),
            metadata(ruleset)
        );
    }
}
