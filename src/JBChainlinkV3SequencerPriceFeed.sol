// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {AggregatorV2V3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV2V3Interface.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import {JBChainlinkV3PriceFeed} from "./JBChainlinkV3PriceFeed.sol";

/// @notice An `IJBPriceFeed` implementation that reports prices from a Chainlink `AggregatorV3Interface` from
/// optimistic sequencers.
contract JBChainlinkV3SequencerPriceFeed is JBChainlinkV3PriceFeed {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBChainlinkV3SequencerPriceFeed_SequencerDownOrRestarting(
        uint256 timestamp, uint256 gradePeriodTime, uint256 startedAt
    );
    error JBChainlinkV3SequencerPriceFeed_InvalidRound();

    //*********************************************************************//
    // ---------------- public stored immutable properties --------------- //
    //*********************************************************************//

    /// @notice How long the sequencer must be re-active in order to return a price.
    uint256 public immutable GRACE_PERIOD_TIME;

    /// @notice The Chainlink sequencer feed that prices are reported from.
    AggregatorV2V3Interface public immutable SEQUENCER_FEED;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param feed The Chainlink feed to report prices from.
    /// @param gracePeriod How long the sequencer should have been re-active before returning prices.
    /// @param sequencerFeed The Chainlink feed to report sequencer status.
    /// @param threshold How many blocks old a price update may be.
    constructor(
        AggregatorV3Interface feed,
        uint256 gracePeriod,
        AggregatorV2V3Interface sequencerFeed,
        uint256 threshold
    )
        JBChainlinkV3PriceFeed(feed, threshold)
    {
        GRACE_PERIOD_TIME = gracePeriod;
        SEQUENCER_FEED = sequencerFeed;
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the current price (per 1 unit) from the feed.
    /// @param decimals The number of decimals the return value should use.
    /// @return The current unit price from the feed, as a fixed point number with the specified number of decimals.
    function currentUnitPrice(uint256 decimals) public view override returns (uint256) {
        // Fetch sequencer status.
        // slither-disable-next-line unused-return
        (, int256 answer, uint256 startedAt,,) = SEQUENCER_FEED.latestRoundData();

        // Check if round is valid to prevent an edge-case where Arbitrum uptime contract is not init.
        if (startedAt == 0) revert JBChainlinkV3SequencerPriceFeed_InvalidRound();

        // Revert if sequencer has too recently restarted or is currently down.
        if (block.timestamp <= GRACE_PERIOD_TIME + startedAt || answer == 1) {
            revert JBChainlinkV3SequencerPriceFeed_SequencerDownOrRestarting(
                block.timestamp, GRACE_PERIOD_TIME, startedAt
            );
        }

        return super.currentUnitPrice(decimals);
    }
}
