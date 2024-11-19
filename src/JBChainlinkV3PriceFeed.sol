// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {IJBPriceFeed} from "./interfaces/IJBPriceFeed.sol";
import {JBFixedPointNumber} from "./libraries/JBFixedPointNumber.sol";

/// @notice An `IJBPriceFeed` implementation that reports prices from a Chainlink `AggregatorV3Interface`.
contract JBChainlinkV3PriceFeed is IJBPriceFeed {
    // A library that provides utility for fixed point numbers.
    using JBFixedPointNumber for uint256;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBChainlinkV3PriceFeed_IncompleteRound();
    error JBChainlinkV3PriceFeed_NegativePrice(int256 price);
    error JBChainlinkV3PriceFeed_StalePrice(uint256 timestamp, uint256 threshold, uint256 updatedAt);
    error JBChainlinkV3PriceFeed_PriceOutOfBounds(int256 price, int256 minAnswer, int256 maxAnswer);

    //*********************************************************************//
    // ---------------- public stored immutable properties --------------- //
    //*********************************************************************//

    /// @notice The Chainlink feed that prices are reported from.
    AggregatorV3Interface public immutable FEED;

    int256 private immutable MIN_ANSWER;
    int256 private immutable MAX_ANSWER;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice How many seconds old a Chainlink price update is allowed to be before considered "stale".
    uint256 public immutable THRESHOLD;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param feed The Chainlink feed to report prices from.
    /// @param threshold How many seconds old a price update may be.
    constructor(AggregatorV3Interface feed, uint256 threshold) {
        FEED = feed;
        THRESHOLD = threshold;

        // Defaults to use if this feed does not have a `minAnswer` and `maxAnswer`.
        int256 _minAnswer = 0;
        int256 _maxAnswer = type(int256).max;

        // If the feed has a `minAnswer` and `maxAnswer`, use those.
        (bool _maxPriceSuccess, bytes memory _maxPrice) =
            address(feed).call(abi.encodeWithSelector(ChainlinkAggregateExtendedInterface.maxAnswer.selector));

        if (_maxPriceSuccess) {
            _maxAnswer = abi.decode(_maxPrice, (int192));
            // We do a regular call since if there is a `maxAnswer` the feed should have a `minAnswer`.
            _minAnswer = ChainlinkAggregateExtendedInterface(address(feed)).minAnswer();
        }

        // Set the min/max bounds.
        MAX_ANSWER = _maxAnswer;
        MIN_ANSWER = _minAnswer;
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the current price (per 1 unit) from the feed.
    /// @param decimals The number of decimals the return value should use.
    /// @return The current unit price from the feed, as a fixed point number with the specified number of decimals.
    function currentUnitPrice(uint256 decimals) public view virtual override returns (uint256) {
        // Get the latest round information from the feed.
        // slither-disable-next-line unused-return
        (, int256 price,, uint256 updatedAt,) = FEED.latestRoundData();

        // Make sure the price's update threshold is met.
        if (block.timestamp > THRESHOLD + updatedAt) {
            revert JBChainlinkV3PriceFeed_StalePrice(block.timestamp, THRESHOLD, updatedAt);
        }

        // Make sure the round is finished.
        // slither-disable-next-line incorrect-equality
        if (updatedAt == 0) revert JBChainlinkV3PriceFeed_IncompleteRound();

        // Make sure the price is positive.
        if (price <= 0) revert JBChainlinkV3PriceFeed_NegativePrice(price);

        // Make sure the price is within the min/max bounds.
        if (price < MIN_ANSWER || price > MAX_ANSWER) {
            revert JBChainlinkV3PriceFeed_PriceOutOfBounds(price, MIN_ANSWER, MAX_ANSWER);
        }

        // Get a reference to the number of decimals the feed uses.
        uint256 feedDecimals = FEED.decimals();

        // Return the price, adjusted to the specified number of decimals.
        return uint256(price).adjustDecimals({decimals: feedDecimals, targetDecimals: decimals});
    }
}

interface ChainlinkAggregateExtendedInterface is AggregatorV3Interface {
    function minAnswer() external view returns (int192);
    function maxAnswer() external view returns (int192);
}
