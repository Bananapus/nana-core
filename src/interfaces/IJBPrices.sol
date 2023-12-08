// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPriceFeed} from "./IJBPriceFeed.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBDirectory} from "./IJBDirectory.sol";

interface IJBPrices {
    event AddPriceFeed(
        uint256 indexed projectId, uint256 indexed pricingCurrency, uint256 indexed unitCurrency, IJBPriceFeed feed
    );

    function PROJECTS() external view returns (IJBProjects);

    function priceFeedFor(
        uint32 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency
    )
        external
        view
        returns (IJBPriceFeed);

    function pricePerUnitOf(
        uint32 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency,
        uint256 decimals
    )
        external
        view
        returns (uint256);

    function addPriceFeedFor(
        uint32 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency,
        IJBPriceFeed priceFeed
    )
        external;
}
