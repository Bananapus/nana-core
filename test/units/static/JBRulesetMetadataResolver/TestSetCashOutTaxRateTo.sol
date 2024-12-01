// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

contract TestSetCashOutTaxRateTo_Local is JBTest {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    function setUp() external {}

    function testFuzzEnsureCorrectlyPackedBits(
        uint16 _fuzzReservedPercent,
        uint16 _fuzzCashOutTaxRate,
        uint16 _fuzzMetadata
    )
        external
    {
        // cash out tax rate should be re-set and re-packed correctly

        address _hookAddress = makeAddr("someting");

        _fuzzReservedPercent = uint16(bound(_fuzzReservedPercent, 0, JBConstants.MAX_RESERVED_PERCENT));
        _fuzzCashOutTaxRate = uint16(bound(_fuzzCashOutTaxRate, 0, JBConstants.MAX_CASH_OUT_TAX_RATE));
        // Ensure the metadata is a max of 14 bits.
        _fuzzMetadata = uint16(bound(_fuzzCashOutTaxRate, 0, 16_383));

        JBRulesetMetadata memory _rulesMetadata = JBRulesetMetadata({
            reservedPercent: _fuzzReservedPercent,
            cashOutTaxRate: _fuzzCashOutTaxRate,
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
            useTotalSurplusForCashOuts: true,
            useDataHookForPay: true,
            useDataHookForCashOut: true,
            dataHook: _hookAddress,
            metadata: _fuzzMetadata
        });

        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        // Reserved Rate
        uint256 _reservedPercent = uint256(uint16(_packed >> 4));

        // Cash out tax rate
        uint256 _cashOutTaxRate = uint256(uint16(_packed >> 20));

        assertEq(_reservedPercent, _fuzzReservedPercent);
        assertEq(_cashOutTaxRate, _fuzzCashOutTaxRate);

        for (uint256 _i = 68; _i < 81; _i++) {
            uint256 _flag = uint256(uint16(_packed >> _i) & 1);
            assertEq(_flag, 1);
        }

        // Data source address
        address _packedDataHook = address(uint160(_packed >> 82));
        assertEq(_packedDataHook, _hookAddress);

        // Metadata
        uint256 _packedMetadata = uint256(uint16(_packed >> 242));
        assertEq(_packedMetadata, uint256(_fuzzMetadata));
    }

    function testFuzzEnsureCorrectlyPackedBits_implementationIndependent(JBRulesetMetadata memory _rulesMetadata)
        external
    {
        // Handle the unique constraints of the JBRulesetMetadata.
        {
            // First 2 bits of `metadata.metadata` are ignored
            _rulesMetadata.metadata = _rulesMetadata.metadata % 16_383;
        }

        // Get the keccak from before.
        bytes32 _before = keccak256(abi.encode(_rulesMetadata));

        // Pack the metadata.
        uint256 _packed = _rulesMetadata.packRulesetMetadata();

        // Unpack the metadata and calculate the new keccak.
        JBRuleset memory _ruleset;
        _ruleset.metadata = _packed;
        JBRulesetMetadata memory _unpackedMetadata = JBRulesetMetadataResolver.expandMetadata(_ruleset);
        bytes32 _after = keccak256(abi.encode(_unpackedMetadata));

        // Compare the before and the after.
        assertEq(_before, _after);
    }
}
