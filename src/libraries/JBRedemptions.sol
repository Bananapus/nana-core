
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {mulDiv} from "@prb/math/src/Common.sol";

import {JBConstants} from "./JBConstants.sol";

/// @notice Redemption calculations.
library JBRedemptions {
    /// @notice Returns the amount of surplus terminal tokens which can be reclaimed based on the total surplus, the number of tokens being redeemed, the total token supply, and the ruleset's redemption rate.
    /// @param surplus The total amount of surplus terminal tokens.
    /// @param tokensRedeemed The number of tokens being redeemed, as a fixed point number with 18 decimals.
    /// @param totalSupply The total token supply, as a fixed point number with 18 decimals.
    /// @param redemptionRate The current ruleset's redemption rate.
    /// @return The amount of surplus tokens that can be reclaimed.
    function reclaimFrom(
        uint256 surplus,
        uint256 tokensRedeemed,
        uint256 totalSupply,
        uint256 redemptionRate
    )
        internal
        pure
        returns (uint256)
    {
        // If the redemption rate is 0, no surplus can be reclaimed.
        if (redemptionRate == 0) return 0;

        // If the total supply is being redeemed, return the entire surplus.
        if (tokensRedeemed == totalSupply) return surplus;

        // Get a reference to the linear proportion.
        uint256 base = mulDiv(surplus, tokensRedeemed, totalSupply);

        // These conditions are all part of the same curve.
        // Edge conditions are separated to minimize the operations performed in those cases.
        if (redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
            return base;
        }

        return mulDiv(
            base,
            redemptionRate + mulDiv(tokensRedeemed, JBConstants.MAX_REDEMPTION_RATE - redemptionRate, totalSupply),
            JBConstants.MAX_REDEMPTION_RATE
        );
    }
}
