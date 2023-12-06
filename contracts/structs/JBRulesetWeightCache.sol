// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member weight The cached weight value.
/// @custom:member decayMultiple The decay multiple that produces the given weight.
struct JBRulesetWeightCache {
    uint256 weight;
    uint256 decayMultiple;
}
