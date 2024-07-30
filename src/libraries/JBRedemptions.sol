// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {mulDiv, sqrt} from "@prb/math/src/Common.sol";

import {JBConstants} from "./JBConstants.sol";

/// @notice Redemption calculations.
library JBRedemptions {
    /// @notice Returns the amount of surplus terminal tokens which can be reclaimed based on the total surplus, the
    /// number of tokens being redeemed, the total token supply, and the ruleset's redemption rate.
    /// @param surplus The total amount of surplus terminal tokens.
    /// @param tokensRedeemed The number of tokens being redeemed, as a fixed point number with 18 decimals.
    /// @param totalSupply The total token supply, as a fixed point number with 18 decimals.
    /// @param redemptionRate The current ruleset's redemption rate.
    /// @return reclaimableSurplus The amount of surplus tokens that can be reclaimed.
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
        if (tokensRedeemed >= totalSupply) return surplus;

        // Get a reference to the linear proportion.
        uint256 base = mulDiv(surplus, tokensRedeemed, totalSupply);

        // These conditions are all part of the same curve.
        // Edge conditions are separated to minimize the operations performed in those cases.
        if (redemptionRate == JBConstants.MAX_REDEMPTION_RATE) {
            return base;
        }

        return mulDiv(
            base,
            redemptionRate + mulDiv(JBConstants.MAX_REDEMPTION_RATE - redemptionRate, tokensRedeemed,  totalSupply),
            JBConstants.MAX_REDEMPTION_RATE
        );
    }
    
    /// @notice Returns the number of tokens being redeemed based on the total surplus,
    /// the reclaimable surplus, the total token supply, and the ruleset's redemption rate.
    /// @param surplus The total amount of surplus terminal tokens.
    /// @param reclaimableSurplus The amount of surplus tokens that can be reclaimed.
    /// @param totalSupply The total token supply, as a fixed point number with 18 decimals.
    /// @param redemptionRate The current ruleset's redemption rate.
    /// @return tokensRedeemed The number of tokens being redeemed, as a fixed point number with 18 decimals.
    function redeemedFrom(
        uint256 surplus,
        uint256 reclaimableSurplus,
        uint256 totalSupply,
        uint256 redemptionRate
    )
        internal
        returns (uint256)
    {
        // If the redemption rate is 0 or the surplus is 0, no tokens can be redeemed.
        if (redemptionRate == 0 || surplus == 0) return 0;
    
        // emit K(1, 1);
        // // Calculate the components of the quadratic formula
        // int256 a = int256(mulDiv(surplus, (JBConstants.MAX_REDEMPTION_RATE - redemptionRate), JBConstants.MAX_REDEMPTION_RATE)); // a = surplus * (1 - redemptionRate / MAX_REDEMPTION_RATE)
        // emit K(2, a);
        // int256 b = int256(mulDiv(mulDiv(surplus, redemptionRate, JBConstants.MAX_REDEMPTION_RATE), totalSupply, 1)); // b = surplus * (redemptionRate / MAX_REDEMPTION_RATE) * totalSupply
        // emit K(3, b);
        // int256 c = -int256(reclaimableSurplus * (totalSupply**2)); // c = -reclaimableSurplus * totalSupply^2 (as an int256 for correct negation handling)
        // emit G(4, c);
        // return positive(a, b, c);

        // Calculate the components of the quadratic formula
        int256 a = int256(mulDiv(surplus, (JBConstants.MAX_REDEMPTION_RATE - redemptionRate), JBConstants.MAX_REDEMPTION_RATE)); // a = surplus * (1 - redemptionRate / MAX_REDEMPTION_RATE)
        int256 b = int256(mulDiv(mulDiv(surplus, redemptionRate, JBConstants.MAX_REDEMPTION_RATE), totalSupply, 1)); // b = surplus * (redemptionRate / MAX_REDEMPTION_RATE) * totalSupply
        int256 c = -int256(mulDiv(mulDiv(reclaimableSurplus, totalSupply, 1), totalSupply, 1)); // c = -reclaimableSurplus * totalSupply^2 (as an int256 for correct negation handling)

        return positive(a, b, c);
    }
    // function positive(int256 a, int256 b, int256 c) public returns(uint256){
    //     int256 root = int256(sqrt(uint256(b**2 - (4*a*c/2*a))));
    //     emit K(6, root);
    //     return uint256(root - b);
    // }
    function positive(int256 a, int256 b, int256 c) internal returns (uint256) {
        // Calculate the discriminant
        int256 discriminant = b * b - 4 * a * c;
        require(discriminant >= 0, "No real roots"); // Ensure the discriminant is non-negative

        // Calculate the square root of the discriminant
        uint256 sqrtDiscriminant = sqrt(uint256(discriminant));

        int256 r = (-b + int256(sqrtDiscriminant)) % (2 * a);

        emit R(r);

        // Calculate the positive root of the quadratic equation
        int256 root = (-b + int256(sqrtDiscriminant)) / (2 * a);

        if (r > 0) root += 1;

        return uint256(root);
    }
    event R(int256 r);

}
