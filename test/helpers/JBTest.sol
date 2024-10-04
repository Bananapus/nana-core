// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBRuleset} from "src/structs/JBRuleset.sol";
import {JBRulesetMetadata} from "src/structs/JBRulesetMetadata.sol";
import {JBRulesetMetadataResolver} from "src/libraries/JBRulesetMetadataResolver.sol";
import {JBConstants} from "src/libraries/JBConstants.sol";
import {IJBRulesetApprovalHook} from "src/interfaces/IJBRulesetApprovalHook.sol";
import "lib/forge-std/src/Test.sol";

contract JBTest is Test {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    function mockExpect(address _where, bytes memory _encodedCall, bytes memory _returns) public {
        vm.mockCall(_where, _encodedCall, _returns);
        vm.expectCall(_where, _encodedCall);
    }

    function generateFriendlyRuleset() public view returns (JBRuleset memory) {
        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: false,
            pauseCreditTransfers: false,
            allowOwnerMinting: true,
            allowSetCustomToken: true,
            allowTerminalMigration: true,
            allowSetTerminals: true,
            ownerMustSendPayouts: false,
            allowSetController: true,
            allowAddAccountingContext: true,
            allowAddPriceFeed: true,
            allowCrosschainSuckerExtension: true,
            holdFees: false,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 packed = _rulesMetadata.packRulesetMetadata();

        return JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 10 days,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: packed
        });
    }

    function generateUnfriendlyRuleset() public view returns (JBRuleset memory) {
        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: JBConstants.MAX_RESERVED_PERCENT,
            redemptionRate: JBConstants.MAX_REDEMPTION_RATE,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: true,
            pauseCreditTransfers: true,
            allowOwnerMinting: false,
            allowSetCustomToken: false,
            allowTerminalMigration: false,
            allowSetTerminals: false,
            ownerMustSendPayouts: true,
            allowSetController: false,
            allowAddAccountingContext: false,
            allowAddPriceFeed: false,
            allowCrosschainSuckerExtension: false,
            holdFees: true,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: false,
            useDataHookForRedeem: false,
            dataHook: address(0),
            metadata: 0
        });

        uint256 packed = _rulesMetadata.packRulesetMetadata();

        return JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: uint48(block.timestamp),
            duration: 10 days,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: packed
        });
    }
}
