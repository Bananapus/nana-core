// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {mulDiv} from "prb-math/src/Common.sol";
import {JBConstants} from "./../libraries/JBConstants.sol";

/// @notice Fee calculations.
library JBFees {
    /// @notice Returns the amount of tokens to pay as a fee out of the specified `amount`.
    /// @dev The resulting fee will be `feePercent` of the REMAINING `amount` after subtracting the fee, not the full
    /// `amount`.
    /// @param amount The amount that the fee is based on, as a fixed point number.
    /// @param feePercent The fee percent, out of `JBConstants.MAX_FEE`.
    /// @return The amount of tokens to pay as a fee, as a fixed point number with the same number of decimals as the
    /// provided `amount`.
    function feeAmountIn(uint256 amount, uint256 feePercent) internal pure returns (uint256) {
        // The amount of tokens from the `amount` to pay as a fee. If reverse, the fee taken from a payout of
        // `amount`.
        return amount - mulDiv(amount, JBConstants.MAX_FEE, feePercent + JBConstants.MAX_FEE);
    }

    /// @notice Returns the fee that would have been paid based on an `amount` which has already had the fee subtracted
    /// from it.
    /// @dev The resulting fee will be `feePercent` of the full `amount`.
    /// @param amount The amount that the fee is based on, as a fixed point number with the same amount of decimals as
    /// this terminal.
    /// @param feePercent The fee percent, out of `JBConstants.MAX_FEE`.
    /// @return The amount of the fee, as a fixed point number with the same amount of decimals as this terminal.
    function feeAmountFrom(uint256 amount, uint256 feePercent) internal pure returns (uint256) {
        // The amount of tokens from the `amount` to pay as a fee. If reverse, the fee taken from a payout of
        // `amount`.
        return mulDiv(amount, feePercent, JBConstants.MAX_FEE);
    }
}
