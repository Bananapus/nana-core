// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {JBRuleset} from "./../structs/JBRuleset.sol";
import {JBRulesetMetadata} from "./../structs/JBRulesetMetadata.sol";

library JBRulesetMetadataResolver {
    function reservedPercent(JBRuleset memory ruleset) internal pure returns (uint16) {
        return uint16(ruleset.metadata >> 4);
    }

    function cashOutTaxRate(JBRuleset memory ruleset) internal pure returns (uint16) {
        // Cash out tax rate is a number 0-10000.
        return uint16(ruleset.metadata >> 20);
    }

    function baseCurrency(JBRuleset memory ruleset) internal pure returns (uint32) {
        // Currency is a number 0-4294967296.
        return uint32(ruleset.metadata >> 36);
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

    function allowSetCustomToken(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 71) & 1) == 1;
    }

    function allowTerminalMigration(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 72) & 1) == 1;
    }

    function allowSetTerminals(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 73) & 1) == 1;
    }

    function allowSetController(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 74) & 1) == 1;
    }

    function allowAddAccountingContext(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 75) & 1) == 1;
    }

    function allowAddPriceFeed(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 76) & 1) == 1;
    }

    function ownerMustSendPayouts(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 77) & 1) == 1;
    }

    function holdFees(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 78) & 1) == 1;
    }

    function useTotalSurplusForCashOuts(JBRuleset memory ruleset) internal pure returns (bool) {
        return ((ruleset.metadata >> 79) & 1) == 1;
    }

    function useDataHookForPay(JBRuleset memory ruleset) internal pure returns (bool) {
        return (ruleset.metadata >> 80) & 1 == 1;
    }

    function useDataHookForCashOut(JBRuleset memory ruleset) internal pure returns (bool) {
        return (ruleset.metadata >> 81) & 1 == 1;
    }

    function dataHook(JBRuleset memory ruleset) internal pure returns (address) {
        return address(uint160(ruleset.metadata >> 82));
    }

    function metadata(JBRuleset memory ruleset) internal pure returns (uint16) {
        return uint16(ruleset.metadata >> 242);
    }

    /// @notice Pack the funding cycle metadata.
    /// @param rulesetMetadata The ruleset metadata to validate and pack.
    /// @return packed The packed uint256 of all metadata params. The first 8 bits specify the version.
    function packRulesetMetadata(JBRulesetMetadata memory rulesetMetadata) internal pure returns (uint256 packed) {
        // version 1 in the bits 0-3 (4 bits).
        packed = 1;
        // reserved percent in bits 4-19 (16 bits).
        packed |= uint256(rulesetMetadata.reservedPercent) << 4;
        // cash out tax rate in bits 20-35 (16 bits).
        // cash out tax rate is a number 0-10000.
        packed |= uint256(rulesetMetadata.cashOutTaxRate) << 20;
        // base currency in bits 36-67 (32 bits).
        // base currency is a number 0-16777215.
        packed |= uint256(rulesetMetadata.baseCurrency) << 36;
        // pause pay in bit 68.
        if (rulesetMetadata.pausePay) packed |= 1 << 68;
        // pause credit transfers in bit 69.
        if (rulesetMetadata.pauseCreditTransfers) packed |= 1 << 69;
        // allow discretionary minting in bit 70.
        if (rulesetMetadata.allowOwnerMinting) packed |= 1 << 70;
        // allow a custom token to be set in bit 71.
        if (rulesetMetadata.allowSetCustomToken) packed |= 1 << 71;
        // allow terminal migration in bit 72.
        if (rulesetMetadata.allowTerminalMigration) packed |= 1 << 72;
        // allow set terminals in bit 73.
        if (rulesetMetadata.allowSetTerminals) packed |= 1 << 73;
        // allow set controller in bit 74.
        if (rulesetMetadata.allowSetController) packed |= 1 << 74;
        // allow add accounting context in bit 75.
        if (rulesetMetadata.allowAddAccountingContext) packed |= 1 << 75;
        // allow add price feed in bit 76.
        if (rulesetMetadata.allowAddPriceFeed) packed |= 1 << 76;
        // allow controller migration in bit 77.
        if (rulesetMetadata.ownerMustSendPayouts) packed |= 1 << 77;
        // hold fees in bit 78.
        if (rulesetMetadata.holdFees) packed |= 1 << 78;
        // useTotalSurplusForCashOuts in bit 79.
        if (rulesetMetadata.useTotalSurplusForCashOuts) packed |= 1 << 79;
        // use pay data source in bit 80.
        if (rulesetMetadata.useDataHookForPay) packed |= 1 << 80;
        // use cash out data source in bit 81.
        if (rulesetMetadata.useDataHookForCashOut) packed |= 1 << 81;
        // data source address in bits 82-241.
        packed |= uint256(uint160(address(rulesetMetadata.dataHook))) << 82;
        // metadata in bits 242-255 (14 bits).
        packed |= (uint256(rulesetMetadata.metadata) & 0x3FFF) << 242;
    }

    /// @notice Expand the funding cycle metadata.
    /// @param ruleset The funding cycle having its metadata expanded.
    /// @return rulesetMetadata The ruleset's metadata object.
    function expandMetadata(JBRuleset memory ruleset) internal pure returns (JBRulesetMetadata memory) {
        return JBRulesetMetadata(
            reservedPercent(ruleset),
            cashOutTaxRate(ruleset),
            baseCurrency(ruleset),
            pausePay(ruleset),
            pauseCreditTransfers(ruleset),
            allowOwnerMinting(ruleset),
            allowSetCustomToken(ruleset),
            allowTerminalMigration(ruleset),
            allowSetTerminals(ruleset),
            allowSetController(ruleset),
            allowAddAccountingContext(ruleset),
            allowAddPriceFeed(ruleset),
            ownerMustSendPayouts(ruleset),
            holdFees(ruleset),
            useTotalSurplusForCashOuts(ruleset),
            useDataHookForPay(ruleset),
            useDataHookForCashOut(ruleset),
            dataHook(ruleset),
            metadata(ruleset)
        );
    }
}
