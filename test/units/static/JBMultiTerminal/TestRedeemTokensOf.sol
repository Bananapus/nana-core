// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestRedeemTokensOf_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenCallerDNHavePermission() external {
        // it will revert UNAUTHORIZED
    }

    modifier whenCallerHasPermission() {
        _;
    }

    function test_GivenRedeemCountGtZero() external whenCallerHasPermission {
        // it will call directory controller of and burnTokensOf
    }

    function test_GivenReclaimAmountGtZeroBeneficiaryIsNotFeelessAndRedemptionRateDneqMAX_REDEMPTION_RATE()
        external
        whenCallerHasPermission
    {
        // it will subtract the fee for the reclaim
    }

    function test_GivenTheTokenIsNative() external whenCallerHasPermission {
        // it will sendValue
    }

    function test_GivenTheTokenIsErc20() external whenCallerHasPermission {
        // it will safeTransfer tokens
    }

    function test_GivenAmountEligibleForFeesDneqZero() external whenCallerHasPermission {
        // it will call directory primaryTerminalOf and process the fee
    }

    modifier whenADataHookIsConfigured() {
        _;
    }

    function test_GivenDataHookReturnsRedeemHookSpecsHookIsFeelessAndTokenIsNative()
        external
        whenADataHookIsConfigured
    {
        // it will pass the full amount to the hook and emit HookAfterRecordRedeem
    }

    function test_GivenDataHookReturnsRedeemHookSpecsHookIsFeelessAndTokenIsErc20()
        external
        whenADataHookIsConfigured
    {
        // it will safeIncreaseAllowance pass the full amount to the hook and emit HookAfterRecordRedeem
    }

    function test_GivenDataHookReturnsRedeemHookSpecsHookIsNotFeelessAndTokenIsNative()
        external
        whenADataHookIsConfigured
    {
        // it will calculate the fee pass the amount to the hook and emit HookAfterRecordRedeem
    }

    function test_GivenDataHookReturnsRedeemHookSpecsHookIsNotFeelessAndTokenIsErc20()
        external
        whenADataHookIsConfigured
    {
        // it will safeIncreaseAllowance pass the amount to the hook and emit HookAfterRecordRedeem
    }
}
