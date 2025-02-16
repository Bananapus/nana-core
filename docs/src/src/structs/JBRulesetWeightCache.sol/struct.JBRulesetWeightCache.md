# JBRulesetWeightCache
[Git Source](https://github.com/Bananapus/nana-core/blob/2998dca2fbd2658e2c8791d6dc8348147d69e28e/src/structs/JBRulesetWeightCache.sol)

**Notes:**
- member: weight The cached weight value.

- member: weightCutMultiple The weight cut multiple that produces the given weight.


```solidity
struct JBRulesetWeightCache {
    uint112 weight;
    uint168 weightCutMultiple;
}
```

