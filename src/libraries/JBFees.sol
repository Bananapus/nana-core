// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {mulDiv} from "@prb/math/src/Common.sol";

import {JBConstants} from "./../libraries/JBConstants.sol";

/// @notice Fee calculations.
library JBFees {
    /// @notice Returns the amount of tokens to pay as a fee relative to the specified `amount`.
    /// @param amountAfterFee The amount that the fee is based on, as a fixed point number.
    /// @param feePercent The fee percent, out of `JBConstants.MAX_FEE`.
    /// @return The amount of tokens to pay as a fee, as a fixed point number with the same number of decimals as the
    /// provided `amount`.
    function feeAmountResultingIn(uint256 amountAfterFee, uint256 feePercent) internal pure returns (uint256) {
        // The amount of tokens from the `amount` to pay as a fee. If reverse, the fee taken from a payout of
        // `amount`.
        return mulDiv(amountAfterFee, JBConstants.MAX_FEE, JBConstants.MAX_FEE - feePercent) - amountAfterFee;
    }

    /// @notice Returns the fee that would have been paid based on an `amount` which has already had the fee subtracted
    /// from it.
    /// @param amountBeforeFee The amount that the fee is based on, as a fixed point number with the same amount of
    /// decimals as
    /// this terminal.
    /// @param feePercent The fee percent, out of `JBConstants.MAX_FEE`.
    /// @return The amount of the fee, as a fixed point number with the same amount of decimals as this terminal.
    function feeAmountFrom(uint256 amountBeforeFee, uint256 feePercent) internal pure returns (uint256) {
        // The amount of tokens from the `amount` to pay as a fee. If reverse, the fee taken from a payout of
        // `amount`.
        return mulDiv(amountBeforeFee, feePercent, JBConstants.MAX_FEE);
    }
}
