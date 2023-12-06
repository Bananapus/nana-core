// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {IJBPriceFeed} from "./interfaces/IJBPriceFeed.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {JBPermissionIds} from "./libraries/JBPermissionIds.sol";

/// @notice Manages and normalizes price feeds. Price feeds are contracts which return the "pricing currency" cost of 1 "unit currency".
contract JBPrices is Ownable, JBPermissioned, IJBPrices {
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

    /// @notice Mints ERC-721s that represent project ownership and transfers.
    IJBProjects public immutable override PROJECTS;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The available price feeds.
    /// @dev The feed returns the `_pricingCurrency` cost for one unit of the `_unitCurrency`.
    /// @custom:param _projectId The ID of the project the feed applies to. Feeds stored in ID 0 are used by default for all projects.
    /// @custom:param _pricingCurrency The currency the feed's resulting price is in terms of.
    /// @custom:param _unitCurrency The currency being priced by the feed.
    mapping(uint256 => mapping(uint256 => mapping(uint256 => IJBPriceFeed))) public override
        priceFeedFor;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Gets the `_pricingCurrency` cost for one unit of the `_unitCurrency`.
    /// @param _projectId The ID of the project to check the feed for. Feeds stored in ID 0 are used by default for all projects.
    /// @param _pricingCurrency The currency the feed's resulting price is in terms of.
    /// @param _unitCurrency The currency being priced by the feed.
    /// @param _decimals The number of decimals the returned fixed point price should include.
    /// @return The `_pricingCurrency` price of 1 `_unitCurrency`, as a fixed point number with the specified number of decimals.
    function pricePerUnitOf(
        uint256 _projectId,
        uint256 _pricingCurrency,
        uint256 _unitCurrency,
        uint256 _decimals
    ) public view override returns (uint256) {
        // If the `_pricingCurrency` is the `_unitCurrency`, return 1 since they have the same price. Include the desired number of decimals.
        if (_pricingCurrency == _unitCurrency) return 10 ** _decimals;

        // Get a reference to the price feed.
        IJBPriceFeed _feed = priceFeedFor[_projectId][_pricingCurrency][_unitCurrency];

        // If the feed exists, return its price.
        if (_feed != IJBPriceFeed(address(0))) return _feed.currentUnitPrice(_decimals);

        // Try getting the inverse feed.
        _feed = priceFeedFor[_projectId][_unitCurrency][_pricingCurrency];

        // If it exists, return the inverse of its price.
        if (_feed != IJBPriceFeed(address(0))) {
            return
                PRBMath.mulDiv(10 ** _decimals, 10 ** _decimals, _feed.currentUnitPrice(_decimals));
        }

        // Check for a default feed (project ID 0) if not found.
        if (_projectId != DEFAULT_PROJECT_ID) {
            return pricePerUnitOf({
                _projectId: DEFAULT_PROJECT_ID,
                _pricingCurrency: _pricingCurrency,
                _unitCurrency: _unitCurrency,
                _decimals: _decimals
            });
        }

        // No price feed available, revert.
        revert PRICE_FEED_NOT_FOUND();
    }

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param _permissions A contract storing permissions.
    /// @param _projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param _owner The address that will own the contract.
    constructor(IJBPermissions _permissions, IJBProjects _projects, address _owner)
        JBPermissioned(_permissions)
        Ownable(_owner)
    {
        PROJECTS = _projects;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Add a price feed for the `_unitCurrency`, priced in terms of the `_pricingCurrency`.
    /// @dev Existing feeds can't be modified. Neither can feeds that have already been set as defaults (project ID 0).
    /// @param _pricingCurrency The currency the feed's resulting price is in terms of.
    /// @param _unitCurrency The currency being priced by the feed.
    /// @param _feed The price feed being added.
    function addPriceFeedFor(
        uint256 _projectId,
        uint256 _pricingCurrency,
        uint256 _unitCurrency,
        IJBPriceFeed _feed
    ) external override {
        // If the message sender is this contract's owner and the `projectId` being set for is the default (0), no permissions necessary.
        // Otherwise, only a project's owner or an operator with the `ADD_PRICE_FEED` permission from that owner can add a feed for a project.
        if (_projectId != DEFAULT_PROJECT_ID || msg.sender != owner()) {
            _requirePermission(
                PROJECTS.ownerOf(_projectId), _projectId, JBPermissionIds.ADD_PRICE_FEED
            );
        }

        // Make sure the currencies aren't 0.
        if (_pricingCurrency == 0 || _unitCurrency == 0) revert INVALID_CURRENCY();

        // Make sure there aren't default feeds for the pair or its inverse.
        if (
            priceFeedFor[DEFAULT_PROJECT_ID][_pricingCurrency][_unitCurrency]
                != IJBPriceFeed(address(0))
                || priceFeedFor[DEFAULT_PROJECT_ID][_unitCurrency][_pricingCurrency]
                    != IJBPriceFeed(address(0))
        ) {
            revert PRICE_FEED_ALREADY_EXISTS();
        }

        // Make sure this project doesn't already have feeds for the pair or its inverse.
        if (
            priceFeedFor[_projectId][_pricingCurrency][_unitCurrency] != IJBPriceFeed(address(0))
                || priceFeedFor[_projectId][_unitCurrency][_pricingCurrency] != IJBPriceFeed(address(0))
        ) revert PRICE_FEED_ALREADY_EXISTS();

        // Store the feed.
        priceFeedFor[_projectId][_pricingCurrency][_unitCurrency] = _feed;

        emit AddPriceFeed(_projectId, _pricingCurrency, _unitCurrency, _feed);
    }
}
