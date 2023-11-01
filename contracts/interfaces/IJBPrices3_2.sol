// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPriceFeed} from './IJBPriceFeed.sol';
import {IJBProjects} from './IJBProjects.sol';

interface IJBPrices3_2 {
  event AddFeed(
    uint256 indexed projectId,
    uint256 indexed currency,
    uint256 indexed base,
    IJBPriceFeed feed
  );

  function DEFAULT_PROJECT_ID() external view returns (uint256);

  function projects() external view returns (IJBProjects);

  function feedFor(
    uint256 projectId,
    uint256 currency,
    uint256 base
  ) external view returns (IJBPriceFeed);

  function priceFor(
    uint256 projectId,
    uint256 currency,
    uint256 base,
    uint256 decimals
  ) external view returns (uint256);

  function addFeedFor(
    uint256 _projectId,
    uint256 currency,
    uint256 base,
    IJBPriceFeed priceFeed
  ) external;
}
