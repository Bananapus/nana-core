// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
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

    error STALE_PRICE();
    error INCOMPLETE_ROUND();
    error NEGATIVE_PRICE();
    error SEQUENCER_DOWN_OR_RESTARTING();

    //*********************************************************************//
    // ---------------- public stored immutable properties --------------- //
    //*********************************************************************//

    /// @notice The Chainlink feed that prices are reported from.
    AggregatorV3Interface public immutable FEED;
    AggregatorV2V3Interface public immutable SEQUENCER_FEED;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice How many blocks old a Chainlink price update is allowed to be before considered "stale".
    uint256 public immutable THRESHOLD;

    /// @notice How long the sequencer must be re-active in order to return a price.
    uint256 private immutable GRACE_PERIOD_TIME;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the current price (per 1 unit) from the feed.
    /// @param decimals The number of decimals the return value should use.
    /// @return The current unit price from the feed, as a fixed point number with the specified number of decimals.
    function currentUnitPrice(uint256 decimals) external view override returns (uint256) {
        // Check the sequencer status
        if (!isSequencerActive()) revert SEQUENCER_DOWN_OR_RESTARTING();

        // Get the latest round information from the feed.
        // slither-disable-next-line unused-return
        (, int256 price,, uint256 updatedAt,) = FEED.latestRoundData();

        // Ensure the price is not stale.
        if (block.timestamp - updatedAt > THRESHOLD) revert STALE_PRICE();

        // Make sure the round is finished.
        if (updatedAt == 0) revert INCOMPLETE_ROUND();

        // Make sure the price is positive.
        if (price < 0) revert NEGATIVE_PRICE();

        // Get a reference to the number of decimals the feed uses.
        uint256 feedDecimals = FEED.decimals();

        // Return the price, adjusted to the specified number of decimals.
        return uint256(price).adjustDecimals({decimals: feedDecimals, targetDecimals: decimals});
    }

    /// @notice Fetches sequencer status and uptime returning a "safe-to-use" status.
    /// @return "safe-to-use" status as t/f
    function isSequencerActive() internal view returns (bool) {
        // Fetch status
        (, int256 answer, uint256 startedAt,,) = SEQUENCER_FEED.latestRoundData();

        if (block.timestamp - startedAt <= GRACE_PERIOD_TIME || answer == 1) return false;

        return true;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param feed The Chainlink feed to report prices from.
    /// @param sequencerFeed The Chainlink feed to report sequencer status.
    /// @param threshold How many blocks old a price update may be.
    /// @param gracePeriod How long the sequencer should have been re-active before returning prices.
    constructor(
        AggregatorV3Interface feed,
        AggregatorV2V3Interface sequencerFeed,
        uint256 threshold,
        uint256 gracePeriod
    ) {
        FEED = feed;
        SEQUENCER_FEED = sequencerFeed;
        THRESHOLD = threshold;
        GRACE_PERIOD_TIME = gracePeriod;
    }
}
