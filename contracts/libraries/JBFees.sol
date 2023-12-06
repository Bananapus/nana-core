// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {JBConstants} from "./../libraries/JBConstants.sol";

/// @notice Fee calculations.
library JBFees {
    /// @notice Returns the amount of tokens to pay as a fee out of the specified `_amount`.
    /// @dev The resulting fee will be `_feePercent` of the REMAINING `_amount` after subtracting the fee, not the full `_amount`.
    /// @param _amount The amount that the fee is based on, as a fixed point number.
    /// @param _feePercent The fee percent, out of `JBConstants.MAX_FEE`.
    /// @return The amount of tokens to pay as a fee, as a fixed point number with the same number of decimals as the provided `_amount`.
    function feeAmountIn(uint256 _amount, uint256 _feePercent) internal pure returns (uint256) {
        // The amount of tokens from the `_amount` to pay as a fee. If reverse, the fee taken from a payout of `_amount`.
        return _amount
            - PRBMath.mulDiv(_amount, JBConstants.MAX_FEE, _feePercent + JBConstants.MAX_FEE);
    }

    /// @notice Returns the fee that would have been paid based on an `_amount` which has already had the fee subtracted from it.
    /// @dev The resulting fee will be `_feePercent` of the full `_amount`.
    /// @param _amount The amount that the fee is based on, as a fixed point number with the same amount of decimals as this terminal.
    /// @param _feePercent The fee percent, out of `JBConstants.MAX_FEE`.
    /// @return The amount of the fee, as a fixed point number with the same amount of decimals as this terminal.
    function feeAmountFrom(uint256 _amount, uint256 _feePercent) internal pure returns (uint256) {
        // The amount of tokens from the `_amount` to pay as a fee. If reverse, the fee taken from a payout of `_amount`.
        return PRBMath.mulDiv(_amount, _feePercent, JBConstants.MAX_FEE);
    }
}
