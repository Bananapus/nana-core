// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PRBMath} from '@paulrberg/contracts/math/PRBMath.sol';
import {JBConstants} from './../libraries/JBConstants.sol';

/// @notice Fee calculations.
library JBFees3_2 {
  /// @notice Returns the fee included in the specified _amount for the specified project.
  /// @param _amount The amount that the fee is based on, as a fixed point number with the same amount of decimals as this terminal.
  /// @param _feePercent The percentage of the fee, out of MAX_FEE.
  /// @return The amount of the fee, as a fixed point number with the same amount of decimals as this terminal.
  function feeIn(uint256 _amount, uint256 _feePercent) internal pure returns (uint256) {
    // The amount of tokens from the `_amount` to pay as a fee. If reverse, the fee taken from a payout of `_amount`.
    return
      _amount - PRBMath.mulDiv(_amount, JBConstants.MAX_FEE, _feePercent + JBConstants.MAX_FEE);
  }

  /// @notice Returns the fee amount paid from a payouts of _amount for the specified project.
  /// @param _amount The amount that the fee is based on, as a fixed point number with the same amount of decimals as this terminal.
  /// @param _feePercent The percentage of the fee, out of MAX_FEE.
  /// @return The amount of the fee, as a fixed point number with the same amount of decimals as this terminal.
  function feeFrom(uint256 _amount, uint256 _feePercent) internal pure returns (uint256) {
    // The amount of tokens from the `_amount` to pay as a fee. If reverse, the fee taken from a payout of `_amount`.
    return PRBMath.mulDiv(_amount, _feePercent, JBConstants.MAX_FEE);
  }
}
