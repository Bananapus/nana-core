// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPricesSetup} from "./JBPricesSetup.sol";

contract TestAddPriceFeedFor_Local is JBPricesSetup {
    function setUp() public {
        super.pricesSetup();
    }

    function test_WhenProjectIdIsTheDEFAULT_PROJECT_IDAndMsgSenderIsTheOwner() external {
        // it should add the price feed without checking permissions
    }

    function test_WhenProjectIdIsNotTheDEFAULT_PROJECT_ID() external {
        // it should require ADD_PRICE_FEED permission from the project's owner or an operator
    }

    function test_WhenPricingCurrencyOrUnitCurrencyIs0() external {
        // it should revert with INVALID_CURRENCY
    }

    function test_WhenADefaultFeedForTheCurrencyPairOrItsInverseAlreadyExists() external {
        // it should revert with PRICE_FEED_ALREADY_EXISTS
    }

    function test_WhenThisProjectAlreadyHasFeedsForTheCurrencyPairOrItsInverse() external {
        // it should revert with PRICE_FEED_ALREADY_EXISTS
    }

    function test_GivenTheAboveConditionsAreMet() external {
        // it should store the feed for the project and currency pair
        // it should emit AddPriceFeed event with projectId, pricingCurrency, unitCurrency, and feed
    }
}
