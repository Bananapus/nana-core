// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

contract TestSetRedemptionRateTo_Local is JBTest {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    function setUp() external {}

    function testFuzzEnsureCorrectlyPackedBits(
        uint16 _fuzzReservedPercent,
        uint16 _fuzzRedemptionRate,
        uint16 _fuzzMetadata
    )
        external
    {
        // redemption rate should be re-set and re-packed correctly

        address _hookAddress = makeAddr("someting");

        _fuzzReservedPercent = uint16(bound(_fuzzReservedPercent, 0, JBConstants.MAX_RESERVED_PERCENT));
        _fuzzRedemptionRate = uint16(bound(_fuzzRedemptionRate, 0, JBConstants.MAX_REDEMPTION_RATE));

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: _fuzzReservedPercent,
            redemptionRate: _fuzzRedemptionRate,
            baseCurrency: uint32(uint160(JBConstants.NATIVE_TOKEN)),
            pausePay: true,
            pauseCreditTransfers: true,
            allowOwnerMinting: true,
            allowSetCustomToken: true,
            allowTerminalMigration: true,
            allowSetTerminals: true,
            ownerMustSendPayouts: true,
            allowSetController: true,
            allowAddAccountingContext: true,
            allowAddPriceFeed: true,
            holdFees: true,
            useTotalSurplusForRedemptions: true,
            useDataHookForPay: true,
            useDataHookForRedeem: true,
            dataHook: _hookAddress,
            metadata: _fuzzMetadata
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        // Reserved Rate
        uint256 _reservedPercent = uint256(uint16(_packed >> 4));

        // Redemption rate
        uint256 _redemptionRate = uint256(uint16(_packed >> 20));

        assertEq(_reservedPercent, _fuzzReservedPercent);
        assertEq(_redemptionRate, _fuzzRedemptionRate);

        for (uint256 _i = 68; _i < 81; _i++) {
            uint256 _flag = uint256(uint16(_packed >> _i) & 1);
            assertEq(_flag, 1);
        }

        // Data source address
        address _packedDataHook = address(uint160(_packed >> 82));
        assertEq(_packedDataHook, _hookAddress);

        // Metadata
        uint256 _packedMetadata = uint256(uint16(_packed >> 242));
        assertEq(_packedMetadata, uint256(_fuzzMetadata >> 2));
    }
}
