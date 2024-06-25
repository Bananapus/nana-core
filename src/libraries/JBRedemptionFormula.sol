// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {mulDiv} from "@prb/math/src/Common.sol";

import {JBConstants} from "./JBConstants.sol";

library JBRedemptionFormula {
    /// @notice The amount of surplus which is available for reclaiming via redemption given the number of tokens being
    /// redeemed, the total supply, the current surplus, and the current ruleset.
    /// @param surplus The surplus amount to make the calculation with.
    /// @param tokenCount The number of tokens to make the calculation with, as a fixed point number with 18 decimals.
    /// @param totalSupply The total supply of tokens to make the calculation with, as a fixed point number with 18
    /// decimals.
    /// @param redemptionRate The redemption rate with which the reclaimable surplus is being calculated.
    /// @return The amount of surplus tokens that can be reclaimed.
    function reclaimableSurplusFrom(
        uint256 surplus,
        uint256 tokenCount,
        uint256 totalSupply,
        uint256 redemptionRate
    )
        internal
        pure
        returns (uint256)
    {
        // If the redemption rate is 0, nothing is claimable.
        if (redemptionRate == 0) return 0;

        // If the amount being redeemed is the total supply, return the rest of the surplus.
        if (tokenCount == totalSupply) return surplus;

        // Get a reference to the linear proportion.
        uint256 base = mulDiv(surplus, tokenCount, totalSupply);

        // These conditions are all part of the same curve. Edge conditions are separated because fewer operation are
        // necessary.
        if (redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
            return base;
        }

        return mulDiv(
            base,
            redemptionRate + mulDiv(tokenCount, JBConstants.MAX_REDEMPTION_RATE - redemptionRate, totalSupply),
            JBConstants.MAX_REDEMPTION_RATE
        );
    }
}
