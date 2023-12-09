// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPriceFeed} from "./IJBPriceFeed.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBDirectory} from "./IJBDirectory.sol";

interface IJBPrices {
    event AddPriceFeed(
        uint32 indexed projectId, uint32 indexed pricingCurrency, uint32 indexed unitCurrency, IJBPriceFeed feed
    );

    function PROJECTS() external view returns (IJBProjects);

    function priceFeedFor(
        uint32 projectId,
        uint32 pricingCurrency,
        uint32 unitCurrency
    )
        external
        view
        returns (IJBPriceFeed);

    function pricePerUnitOf(
        uint32 projectId,
        uint32 pricingCurrency,
        uint32 unitCurrency,
        uint8 decimals
    )
        external
        view
        returns (uint160);

    function addPriceFeedFor(
        uint32 projectId,
        uint32 pricingCurrency,
        uint32 unitCurrency,
        IJBPriceFeed priceFeed
    )
        external;
}
