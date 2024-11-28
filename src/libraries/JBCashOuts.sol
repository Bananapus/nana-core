// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {mulDiv} from "@prb/math/src/Common.sol";

import {JBConstants} from "./JBConstants.sol";

/// @notice Cash out calculations.
library JBCashOuts {
    /// @notice Returns the amount of surplus terminal tokens which can be reclaimed based on the total surplus, the
    /// number of tokens being cashed out, the total token supply, and the ruleset's cash out tax rate.
    /// @param surplus The total amount of surplus terminal tokens.
    /// @param cashOutCount The number of tokens being cashed out, as a fixed point number with 18 decimals.
    /// @param totalSupply The total token supply, as a fixed point number with 18 decimals.
    /// @param cashOutTaxRate The current ruleset's cash out tax rate.
    /// @return reclaimableSurplus The amount of surplus tokens that can be reclaimed.
    function cashOutFrom(
        uint256 surplus,
        uint256 cashOutCount,
        uint256 totalSupply,
        uint256 cashOutTaxRate
    )
        internal
        pure
        returns (uint256)
    {
        // If the cash out tax rate is 0, no surplus can be reclaimed.
        if (cashOutTaxRate == JBConstants.MAX_CASH_OUT_TAX_RATE) return 0;

        // If the total supply is being cashed out, return the entire surplus.
        if (cashOutCount >= totalSupply) return surplus;

        // Get a reference to the linear proportion.
        uint256 base = mulDiv(surplus, cashOutCount, totalSupply);

        // These conditions are all part of the same curve.
        // Edge conditions are separated to minimize the operations performed in those cases.
        if (cashOutTaxRate == 0) {
            return base;
        }

        // TODO, im not convinced this is correct yet.
        return mulDiv(
            base,
            (JBConstants.MAX_CASH_OUT_TAX_RATE - cashOutTaxRate) + mulDiv(cashOutTaxRate, cashOutCount, totalSupply),
            JBConstants.MAX_CASH_OUT_TAX_RATE
        );
    }
}
