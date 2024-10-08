// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {mulDiv} from "@prb/math/src/Common.sol";

import {JBControlled} from "./abstract/JBControlled.sol";
import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBPriceFeed} from "./interfaces/IJBPriceFeed.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";

/// @notice Manages and normalizes price feeds. Price feeds are contracts which return the "pricing currency" cost of 1
/// "unit currency".
contract JBPrices is JBControlled, JBPermissioned, Ownable, IJBPrices {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBPrices_PriceFeedAlreadyExists(IJBPriceFeed feed);
    error JBPrices_PriceFeedNotFound();
    error JBPrices_ZeroPricingCurrency();
    error JBPrices_ZeroUnitCurrency();

    //*********************************************************************//
    // ------------------------- public constants ------------------------ //
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
    /// @dev The feed returns the `pricingCurrency` cost for one unit of the `unitCurrency`.
    /// @custom:param projectId The ID of the project the feed applies to. Feeds stored in ID 0 are used by default for
    /// all projects.
    /// @custom:param pricingCurrency The currency the feed's resulting price is in terms of.
    /// @custom:param unitCurrency The currency being priced by the feed.
    mapping(uint256 projectId => mapping(uint256 pricingCurrency => mapping(uint256 unitCurrency => IJBPriceFeed)))
        public
        override priceFeedFor;

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    /// @param permissions A contract storing permissions.
    /// @param projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param owner The address that will own the contract.
    constructor(
        IJBDirectory directory,
        IJBPermissions permissions,
        IJBProjects projects,
        address owner
    )
        JBControlled(directory)
        JBPermissioned(permissions)
        Ownable(owner)
    {
        PROJECTS = projects;
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Gets the `pricingCurrency` cost for one unit of the `unitCurrency`.
    /// @param projectId The ID of the project to check the feed for. Feeds stored in ID 0 are used by default for all
    /// projects.
    /// @param pricingCurrency The currency the feed's resulting price is in terms of.
    /// @param unitCurrency The currency being priced by the feed.
    /// @param decimals The number of decimals the returned fixed point price should include.
    /// @return The `pricingCurrency` price of 1 `unitCurrency`, as a fixed point number with the specified number of
    /// decimals.
    function pricePerUnitOf(
        uint256 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency,
        uint256 decimals
    )
        public
        view
        override
        returns (uint256)
    {
        // If the `pricingCurrency` is the `unitCurrency`, return 1 since they have the same price. Include the
        // desired number of decimals.
        if (pricingCurrency == unitCurrency) return 10 ** decimals;

        // Get a reference to the price feed.
        IJBPriceFeed feed = priceFeedFor[projectId][pricingCurrency][unitCurrency];

        // If the feed exists, return its price.
        if (feed != IJBPriceFeed(address(0))) return feed.currentUnitPrice(decimals);

        // Try getting the inverse feed.
        feed = priceFeedFor[projectId][unitCurrency][pricingCurrency];

        // If it exists, return the inverse of its price.
        if (feed != IJBPriceFeed(address(0))) {
            return mulDiv(10 ** decimals, 10 ** decimals, feed.currentUnitPrice(decimals));
        }

        // Check for a default feed (project ID 0) if not found.
        if (projectId != DEFAULT_PROJECT_ID) {
            return pricePerUnitOf({
                projectId: DEFAULT_PROJECT_ID,
                pricingCurrency: pricingCurrency,
                unitCurrency: unitCurrency,
                decimals: decimals
            });
        }

        // No price feed available, revert.
        revert JBPrices_PriceFeedNotFound();
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Add a price feed for the `unitCurrency`, priced in terms of the `pricingCurrency`.
    /// @dev Price feeds can only be added, not modified or removed.
    /// @dev This contract's owner can add protocol-wide default price feed by passing a `projectId` of 0.
    /// @param projectId The ID of the project to add a feed for. If `projectId` is 0, add a protocol-wide default price
    /// feed.
    /// @param pricingCurrency The currency the feed's output price is in terms of.
    /// @param unitCurrency The currency being priced by the feed.
    /// @param feed The address of the price feed to add.
    function addPriceFeedFor(
        uint256 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency,
        IJBPriceFeed feed
    )
        external
        override
    {
        // Ensure default price feeds can only be set by this contract's owner, and that other `projectId`s can only be
        // set by the controller
        projectId == DEFAULT_PROJECT_ID ? _checkOwner() : _onlyControllerOf(projectId);

        // Make sure the pricing currency isn't 0.
        if (pricingCurrency == 0) revert JBPrices_ZeroPricingCurrency();

        // Make sure the unit currency isn't 0.
        if (unitCurrency == 0) revert JBPrices_ZeroUnitCurrency();

        // Make sure there isn't already a default price feed for the pair or its inverse.
        if (
            priceFeedFor[DEFAULT_PROJECT_ID][pricingCurrency][unitCurrency] != IJBPriceFeed(address(0))
                || priceFeedFor[DEFAULT_PROJECT_ID][unitCurrency][pricingCurrency] != IJBPriceFeed(address(0))
        ) {
            revert JBPrices_PriceFeedAlreadyExists(
                priceFeedFor[DEFAULT_PROJECT_ID][pricingCurrency][unitCurrency] != IJBPriceFeed(address(0))
                    ? priceFeedFor[DEFAULT_PROJECT_ID][pricingCurrency][unitCurrency]
                    : priceFeedFor[DEFAULT_PROJECT_ID][unitCurrency][pricingCurrency]
            );
        }

        // Make sure this project doesn't already have a price feed for the pair or its inverse.
        if (
            priceFeedFor[projectId][pricingCurrency][unitCurrency] != IJBPriceFeed(address(0))
                || priceFeedFor[projectId][unitCurrency][pricingCurrency] != IJBPriceFeed(address(0))
        ) {
            revert JBPrices_PriceFeedAlreadyExists(
                priceFeedFor[projectId][pricingCurrency][unitCurrency] != IJBPriceFeed(address(0))
                    ? priceFeedFor[projectId][pricingCurrency][unitCurrency]
                    : priceFeedFor[projectId][unitCurrency][pricingCurrency]
            );
        }

        // Store the feed.
        priceFeedFor[projectId][pricingCurrency][unitCurrency] = feed;

        emit AddPriceFeed({
            projectId: projectId,
            pricingCurrency: pricingCurrency,
            unitCurrency: unitCurrency,
            feed: feed,
            caller: msg.sender
        });
    }
}
