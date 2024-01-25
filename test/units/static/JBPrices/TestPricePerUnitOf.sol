// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPricesSetup} from "./JBPricesSetup.sol";

contract TestPricePerUnitOf_Local is JBPricesSetup {
    function setUp() public {
        super.pricesSetup();
    }

    function test_WhenPricingCurrencyIsTheSameAsUnitCurrency() external {
        // it should return 1 with requested decimals
    }

    function test_WhenPriceFeedExistsForProjectIdAndPricingCurrencyToUnitCurrency() external {
        // it should return the current price from price feed
    }

    function test_WhenInversePriceFeedExistsForProjectIdAndUnitCurrencyToPricingCurrency() external {
        // it should return the inverse of the current price from inverse price feed
    }

    function test_WhenProjectIdIsNotTheDEFAULT_PROJECT_IDAndNoDirectOrInversePriceFeedIsFound() external {
        // it should attempt to use the default price feed for DEFAULT_PROJECT_ID
    }

    function test_WhenNoPriceFeedIsFoundOrExistsIncludingDefaultCase() external {
        // it should revert with PRICE_FEED_NOT_FOUND
    }
}
