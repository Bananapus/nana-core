// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {JBOperatable} from './abstract/JBOperatable.sol';
import {PRBMath} from '@paulrberg/contracts/math/PRBMath.sol';
import {IJBPriceFeed} from './interfaces/IJBPriceFeed.sol';
import {IJBProjects} from './interfaces/IJBProjects.sol';
import {IJBOperatorStore} from './interfaces/IJBOperatorStore.sol';
import {IJBPrices3_2} from './interfaces/IJBPrices3_2.sol';
import {JBOperations2} from './libraries/JBOperations2.sol';

/// @notice Manages and normalizes price feeds.
contract JBPrices3_2 is Ownable, JBOperatable, IJBPrices3_2 {
  //*********************************************************************//
  // --------------------------- custom errors ------------------------- //
  //*********************************************************************//
  error INVALID_CURRENCY();
  error PRICE_FEED_ALREADY_EXISTS();
  error PRICE_FEED_NOT_FOUND();

  //*********************************************************************//
  // --------------------- internal stored constants ------------------- //
  //*********************************************************************//

  /// @notice The ID to store default values in.
  uint256 public constant override DEFAULT_PROJECT_ID = 0;

  //*********************************************************************//
  // ---------------- public immutable stored properties --------------- //
  //*********************************************************************//

  /// @notice Mints ERC-721's that represent project ownership and transfers.
  IJBProjects public immutable override projects;

  //*********************************************************************//
  // --------------------- public stored properties -------------------- //
  //*********************************************************************//

  /// @notice The available price feeds.
  /// @dev The feed returns the number of `_currency` units that can be converted to 1 `_base` unit.
  /// @custom:param _projectId The ID of the project for which the feed applies. Feeds stored in ID 0 are used by default.
  /// @custom:param _currency The currency units the feed's resulting price is in terms of.
  /// @custom:param _base The base currency unit being priced by the feed.
  mapping(uint256 => mapping(uint256 => mapping(uint256 => IJBPriceFeed))) public override feedFor;

  //*********************************************************************//
  // -------------------------- public views --------------------------- //
  //*********************************************************************//

  /// @notice Gets the number of `_currency` units that can be converted to 1 `_base` unit.
  /// @param _projectId The ID of the project relative to which the feed used to derive the price belongs. Feeds stored in ID 0 are used by default.
  /// @param _currency The currency units the resulting price is in terms of.
  /// @param _base The base currency unit being priced.
  /// @param _decimals The number of decimals the returned fixed point price should include.
  /// @return The price of the currency in terms of the base, as a fixed point number with the specified number of decimals.
  function priceFor(
    uint256 _projectId,
    uint256 _currency,
    uint256 _base,
    uint256 _decimals
  ) public view override returns (uint256) {
    // If the currency is the base, return 1 since they are priced the same. Include the desired number of decimals.
    if (_currency == _base) return 10 ** _decimals;

    // Get a reference to the feed.
    IJBPriceFeed _feed = feedFor[_projectId][_currency][_base];

    // If it exists, return the price.
    if (_feed != IJBPriceFeed(address(0))) return _feed.currentPrice(_decimals);

    // Get the inverse feed.
    _feed = feedFor[_projectId][_base][_currency];

    // If it exists, return the inverse price.
    if (_feed != IJBPriceFeed(address(0)))
      return PRBMath.mulDiv(10 ** _decimals, 10 ** _decimals, _feed.currentPrice(_decimals));

    // Check in the 0 project if not found.
    if (_projectId != 0)
      return priceFor({_projectId: 0, _currency: _currency, _base: _base, _decimals: _decimals});

    // No price feed available, revert.
    revert PRICE_FEED_NOT_FOUND();
  }

  //*********************************************************************//
  // ---------------------------- constructor -------------------------- //
  //*********************************************************************//

  /// @param _operatorStore A contract storing operator assignments.
  /// @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
  /// @param _owner The address that will own the contract.
  constructor(
    IJBOperatorStore _operatorStore,
    IJBProjects _projects,
    address _owner
  ) JBOperatable(_operatorStore) {
    projects = _projects;
    // Transfer the ownership.
    transferOwnership(_owner);
  }

  //*********************************************************************//
  // ---------------------- external transactions ---------------------- //
  //*********************************************************************//

  /// @notice Add a price feed for a currency in terms of the provided base currency.
  /// @dev Current feeds can't be modified, neither can feeds that have already been set by the default.
  /// @param _currency The currency units the feed's resulting price is in terms of.
  /// @param _base The base currency unit being priced by the feed.
  /// @param _feed The price feed being added.
  function addFeedFor(
    uint256 _projectId,
    uint256 _currency,
    uint256 _base,
    IJBPriceFeed _feed
  )
    external
    override
    requirePermissionAllowingOverride(
      projects.ownerOf(_projectId),
      _projectId,
      JBOperations2.ADD_PRICE_FEED,
      msg.sender == owner() && _projectId == 0
    )
  {
    // Make sure the currencies aren't 0.
    if (_currency == 0 || _base == 0) revert INVALID_CURRENCY();

    // Make sure there's no feed stored for the pair as defaults.
    if (
      feedFor[0][_currency][_base] != IJBPriceFeed(address(0)) ||
      feedFor[0][_base][_currency] != IJBPriceFeed(address(0))
    ) {
      revert PRICE_FEED_ALREADY_EXISTS();
    }

    // There can't already be a feed for the specified currency.
    if (
      feedFor[_projectId][_currency][_base] != IJBPriceFeed(address(0)) ||
      feedFor[_projectId][_base][_currency] != IJBPriceFeed(address(0))
    ) revert PRICE_FEED_ALREADY_EXISTS();

    // Store the feed.
    feedFor[_projectId][_currency][_base] = _feed;

    emit AddFeed(_projectId, _currency, _base, _feed);
  }
}
