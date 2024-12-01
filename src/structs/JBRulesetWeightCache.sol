// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member weight The cached weight value.
/// @custom:member weightCutMultiple The weight cut multiple that produces the given weight.
struct JBRulesetWeightCache {
    uint112 weight;
    uint168 weightCutMultiple;
}
