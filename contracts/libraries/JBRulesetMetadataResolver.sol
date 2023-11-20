// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {JBFundingCycle} from "./../structs/JBFundingCycle.sol";
import {JBFundingCycleMetadata} from "./../structs/JBFundingCycleMetadata.sol";
import {JBGlobalFundingCycleMetadata} from "./../structs/JBGlobalFundingCycleMetadata.sol";
import {JBConstants} from "./JBConstants.sol";
import {JBGlobalFundingCycleMetadataResolver} from "./JBGlobalFundingCycleMetadataResolver.sol";

library JBFundingCycleMetadataResolver {
    function global(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (JBGlobalFundingCycleMetadata memory)
    {
        return
            JBGlobalFundingCycleMetadataResolver.expandMetadata(uint8(_fundingCycle.metadata >> 8));
    }

    function reservedRate(JBFundingCycle memory _fundingCycle) internal pure returns (uint256) {
        return uint256(uint16(_fundingCycle.metadata >> 16));
    }

    function redemptionRate(JBFundingCycle memory _fundingCycle) internal pure returns (uint256) {
        // Redemption rate is a number 0-10000.
        return uint256(uint16(_fundingCycle.metadata >> 32));
    }

    function baseCurrency(JBFundingCycle memory _fundingCycle) internal pure returns (uint256) {
        // Currency is a number 0-4294967296.
        return uint256(uint32(_fundingCycle.metadata >> 48));
    }

    function payPaused(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
        return ((_fundingCycle.metadata >> 80) & 1) == 1;
    }

    function mintingAllowed(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
        return ((_fundingCycle.metadata >> 81) & 1) == 1;
    }

    function terminalMigrationAllowed(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (bool)
    {
        return ((_fundingCycle.metadata >> 82) & 1) == 1;
    }

    function controllerMigrationAllowed(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (bool)
    {
        return ((_fundingCycle.metadata >> 83) & 1) == 1;
    }

    function shouldHoldFees(JBFundingCycle memory _fundingCycle) internal pure returns (bool) {
        return ((_fundingCycle.metadata >> 84) & 1) == 1;
    }

    function useTotalOverflowForRedemptions(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (bool)
    {
        return ((_fundingCycle.metadata >> 85) & 1) == 1;
    }

    function useDataSourceForPay(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (bool)
    {
        return (_fundingCycle.metadata >> 86) & 1 == 1;
    }

    function useDataSourceForRedeem(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (bool)
    {
        return (_fundingCycle.metadata >> 87) & 1 == 1;
    }

    function dataSource(JBFundingCycle memory _fundingCycle) internal pure returns (address) {
        return address(uint160(_fundingCycle.metadata >> 88));
    }

    function metadata(JBFundingCycle memory _fundingCycle) internal pure returns (uint256) {
        return uint256(uint8(_fundingCycle.metadata >> 248));
    }

    /// @notice Pack the funding cycle metadata.
    /// @param _metadata The metadata to validate and pack.
    /// @return packed The packed uint256 of all metadata params. The first 8 bits specify the version.
    function packFundingCycleMetadata(JBFundingCycleMetadata memory _metadata)
        internal
        pure
        returns (uint256 packed)
    {
        // version 1 in the bits 0-7 (8 bits).
        packed = 1;
        // global metadata in bits 8-15 (8 bits).
        packed |= JBGlobalFundingCycleMetadataResolver.packFundingCycleGlobalMetadata(
            _metadata.global
        ) << 8;
        // reserved rate in bits 16-31 (16 bits).
        packed |= _metadata.reservedRate << 16;
        // redemption rate in bits 32-47 (16 bits).
        // redemption rate is a number 0-10000.
        packed |= _metadata.redemptionRate << 32;
        // base currency in bits 48-79 (32 bits).
        // base currency is a number 0-16777215.
        packed |= _metadata.baseCurrency << 48;
        // pause pay in bit 80.
        if (_metadata.pausePay) packed |= 1 << 80;
        // allow minting in bit 81.
        if (_metadata.allowMinting) packed |= 1 << 81;
        // allow terminal migration in bit 82.
        if (_metadata.allowTerminalMigration) packed |= 1 << 82;
        // allow controller migration in bit 83.
        if (_metadata.allowControllerMigration) packed |= 1 << 83;
        // hold fees in bit 84.
        if (_metadata.holdFees) packed |= 1 << 84;
        // useTotalOverflowForRedemptions in bit 85.
        if (_metadata.useTotalOverflowForRedemptions) packed |= 1 << 85;
        // use pay data source in bit 86.
        if (_metadata.useDataSourceForPay) packed |= 1 << 86;
        // use redeem data source in bit 87.
        if (_metadata.useDataSourceForRedeem) packed |= 1 << 87;
        // data source address in bits 88-247.
        packed |= uint256(uint160(address(_metadata.dataSource))) << 88;
        // metadata in bits 248-255 (8 bits).
        packed |= _metadata.metadata << 248;
    }

    /// @notice Expand the funding cycle metadata.
    /// @param _fundingCycle The funding cycle having its metadata expanded.
    /// @return metadata The metadata object.
    function expandMetadata(JBFundingCycle memory _fundingCycle)
        internal
        pure
        returns (JBFundingCycleMetadata memory)
    {
        return JBFundingCycleMetadata(
            global(_fundingCycle),
            reservedRate(_fundingCycle),
            redemptionRate(_fundingCycle),
            baseCurrency(_fundingCycle),
            payPaused(_fundingCycle),
            mintingAllowed(_fundingCycle),
            terminalMigrationAllowed(_fundingCycle),
            controllerMigrationAllowed(_fundingCycle),
            shouldHoldFees(_fundingCycle),
            useTotalOverflowForRedemptions(_fundingCycle),
            useDataSourceForPay(_fundingCycle),
            useDataSourceForRedeem(_fundingCycle),
            dataSource(_fundingCycle),
            metadata(_fundingCycle)
        );
    }
}
