// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {mulDiv} from "@prb/math/src/Common.sol";

import {JBControlled} from "./abstract/JBControlled.sol";
import {JBApprovalStatus} from "./enums/JBApprovalStatus.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBRulesetApprovalHook} from "./interfaces/IJBRulesetApprovalHook.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";
import {JBRulesetWeightCache} from "./structs/JBRulesetWeightCache.sol";

/// @notice Manages rulesets and queuing.
/// @dev Rulesets dictate how a project behaves for a period of time. To learn more about their functionality, see the
/// `JBRuleset` data structure.
/// @dev Throughout this contract, `rulesetId` is an identifier for each ruleset. The `rulesetId` is the unix timestamp
/// when the ruleset was initialized.
/// @dev `approvable` means a ruleset which may or may not be approved.
contract JBRulesets is JBControlled, IJBRulesets {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBRulesets_InvalidWeightCutPercent(uint256 percent);
    error JBRulesets_InvalidRulesetApprovalHook(IJBRulesetApprovalHook hook);
    error JBRulesets_InvalidRulesetDuration(uint256 duration, uint256 limit);
    error JBRulesets_InvalidRulesetEndTime(uint256 timestamp, uint256 limit);
    error JBRulesets_InvalidWeight(uint256 weight, uint256 limit);

    //*********************************************************************//
    // ------------------------- internal constants ----------------------- //
    //*********************************************************************//

    /// @notice The number of weight cut percent multiples before a cached value is sought.
    uint256 internal constant _WEIGHT_CUT_MULTIPLE_CACHE_LOOKUP_THRESHOLD = 1000;

    /// @notice The maximum number of weight cut percent multiples that can be cached at a time.
    uint256 internal constant _MAX_WEIGHT_CUT_MULTIPLE_CACHE_THRESHOLD = 50_000;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The ID of the ruleset with the latest start time for a specific project, whether the ruleset has been
    /// approved or not.
    /// @dev If a project has multiple rulesets queued, the `latestRulesetIdOf` will be the last one. This is the
    /// "changeable" cycle.
    /// @custom:param projectId The ID of the project to get the latest ruleset ID of.
    /// @return latestRulesetIdOf The `rulesetId` of the project's latest ruleset.
    mapping(uint256 projectId => uint256) public override latestRulesetIdOf;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------- //
    //*********************************************************************//

    /// @notice The metadata for each ruleset, packed into one storage slot.
    /// @custom:param projectId The ID of the project to get metadata of.
    /// @custom:param rulesetId The ID of the ruleset to get metadata of.
    mapping(uint256 projectId => mapping(uint256 rulesetId => uint256)) internal _metadataOf;

    /// @notice The mechanism-added properties to manage and schedule each ruleset, packed into one storage slot.
    /// @custom:param projectId The ID of the project to get the intrinsic properties of.
    /// @custom:param rulesetId The ID of the ruleset to get the intrinsic properties of.
    mapping(uint256 projectId => mapping(uint256 rulesetId => uint256)) internal _packedIntrinsicPropertiesOf;

    /// @notice The user-defined properties of each ruleset, packed into one storage slot.
    /// @custom:param projectId The ID of the project to get the user-defined properties of.
    /// @custom:param rulesetId The ID of the ruleset to get the user-defined properties of.
    mapping(uint256 projectId => mapping(uint256 rulesetId => uint256)) internal _packedUserPropertiesOf;

    /// @notice Cached weight values to derive rulesets from.
    /// @custom:param projectId The ID of the project to which the cache applies.
    /// @custom:param rulesetId The ID of the ruleset to which the cache applies.
    mapping(uint256 projectId => mapping(uint256 rulesetId => JBRulesetWeightCache)) internal _weightCacheOf;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    // solhint-disable-next-line no-empty-blocks
    constructor(IJBDirectory directory) JBControlled(directory) {}

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Get an array of a project's rulesets up to a maximum array size, sorted from latest to earliest.
    /// @param projectId The ID of the project to get the rulesets of.
    /// @param startingId The ID of the ruleset to begin with. This will be the latest ruleset in the result. If 0 is
    /// passed, the project's latest ruleset will be used.
    /// @param size The maximum number of rulesets to return.
    /// @return rulesets The rulesets as an array of `JBRuleset` structs.
    function allOf(
        uint256 projectId,
        uint256 startingId,
        uint256 size
    )
        external
        view
        override
        returns (JBRuleset[] memory rulesets)
    {
        // If no starting ID was provided, set it to the latest ruleset's ID.
        if (startingId == 0) startingId = latestRulesetIdOf[projectId];

        // Keep a reference to the number of rulesets being returned.
        uint256 count = 0;

        // Keep a reference to the starting ruleset.
        JBRuleset memory ruleset = _getStructFor(projectId, startingId);

        // First, count the number of rulesets to include in the result by iterating backwards from the starting
        // ruleset.
        while (ruleset.id != 0 && count < size) {
            // Increment the counter.
            count++;

            // Iterate to the ruleset it was based on.
            ruleset = _getStructFor(projectId, ruleset.basedOnId);
        }

        // Keep a reference to the array of rulesets that'll be populated.
        rulesets = new JBRuleset[](count);

        // Return an empty array if there are no rulesets to return.
        if (count == 0) {
            return rulesets;
        }

        // Reset the ruleset being iterated on to the starting ruleset.
        ruleset = _getStructFor(projectId, startingId);

        // Set the counter.
        uint256 i;

        // Populate the array of rulesets to return.
        while (i < count) {
            // Add the ruleset to the array.
            rulesets[i++] = ruleset;

            // Get the ruleset it was based on if needed.
            if (i != count) ruleset = _getStructFor(projectId, ruleset.basedOnId);
        }
    }

    /// @notice The current approval status of a given project's latest ruleset.
    /// @param projectId The ID of the project to check the approval status of.
    /// @return The project's current approval status.
    function currentApprovalStatusForLatestRulesetOf(uint256 projectId)
        external
        view
        override
        returns (JBApprovalStatus)
    {
        // Get a reference to the latest ruleset ID.
        uint256 rulesetId = latestRulesetIdOf[projectId];

        // Resolve the struct for the latest ruleset.
        JBRuleset memory ruleset = _getStructFor(projectId, rulesetId);

        return _approvalStatusOf({projectId: projectId, ruleset: ruleset});
    }

    /// @notice The ruleset that is currently active for the specified project.
    /// @dev If a current ruleset of the project is not found, returns an empty ruleset with all properties set to 0.
    /// @param projectId The ID of the project to get the current ruleset of.
    /// @return ruleset The project's current ruleset.
    function currentOf(uint256 projectId) external view override returns (JBRuleset memory ruleset) {
        // If the project does not have a ruleset, return an empty struct.
        // slither-disable-next-line incorrect-equality
        if (latestRulesetIdOf[projectId] == 0) return _getStructFor(0, 0);

        // Get a reference to the currently approvable ruleset's ID.
        uint256 rulesetId = _currentlyApprovableRulesetIdOf(projectId);

        // If a currently approvable ruleset exists...
        if (rulesetId != 0) {
            // Resolve the struct for the currently approvable ruleset.
            ruleset = _getStructFor(projectId, rulesetId);

            // Get a reference to the approval status.
            JBApprovalStatus approvalStatus = _approvalStatusOf(projectId, ruleset);

            // Check to see if this ruleset's approval hook is approved if it exists.
            // If so, return it.
            // slither-disable-next-line incorrect-equality
            if (approvalStatus == JBApprovalStatus.Approved || approvalStatus == JBApprovalStatus.Empty) {
                return ruleset;
            }

            // If it hasn't been approved, set the ruleset configuration to be the configuration of the ruleset that
            // it's based on,
            // which carries the last approved configuration.
            rulesetId = ruleset.basedOnId;

            // Keep a reference to its ruleset.
            ruleset = _getStructFor(projectId, rulesetId);
        } else {
            // No upcoming ruleset found that is currently approvable,
            // so use the latest ruleset ID.
            rulesetId = latestRulesetIdOf[projectId];

            // Get the struct for the latest ID.
            ruleset = _getStructFor(projectId, rulesetId);

            // Get a reference to the approval status.
            JBApprovalStatus approvalStatus = _approvalStatusOf(projectId, ruleset);

            // While the ruleset has a approval hook that isn't approved or if it hasn't yet started, get a reference to
            // the ruleset that the latest is based on, which has the latest approved configuration.
            while (
                (approvalStatus != JBApprovalStatus.Approved && approvalStatus != JBApprovalStatus.Empty)
                    || block.timestamp < ruleset.start
            ) {
                rulesetId = ruleset.basedOnId;
                ruleset = _getStructFor(projectId, rulesetId);
                approvalStatus = _approvalStatusOf(projectId, ruleset);
            }
        }

        // If the base has no duration, it's still the current one.
        // slither-disable-next-line incorrect-equality
        if (ruleset.duration == 0) return ruleset;

        // Return a simulation of the current ruleset.
        return _simulateCycledRulesetBasedOn({projectId: projectId, baseRuleset: ruleset, allowMidRuleset: true});
    }

    /// @notice Get the ruleset struct for a given `rulesetId` and `projectId`.
    /// @param projectId The ID of the project to which the ruleset belongs.
    /// @param rulesetId The ID of the ruleset to get the struct of.
    /// @return ruleset The ruleset struct.
    function getRulesetOf(
        uint256 projectId,
        uint256 rulesetId
    )
        external
        view
        override
        returns (JBRuleset memory ruleset)
    {
        return _getStructFor(projectId, rulesetId);
    }

    /// @notice The latest ruleset queued for a project. Returns the ruleset's struct and its current approval status.
    /// @dev Returns struct and status for the ruleset initialized furthest in the future (at the end of the ruleset
    /// queue).
    /// @param projectId The ID of the project to get the latest queued ruleset of.
    /// @return ruleset The project's latest queued ruleset's struct.
    /// @return approvalStatus The approval hook's status for the ruleset.
    function latestQueuedOf(uint256 projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus)
    {
        // Get a reference to the latest ruleset's ID.
        uint256 rulesetId = latestRulesetIdOf[projectId];

        // Resolve the struct for the latest ruleset.
        ruleset = _getStructFor(projectId, rulesetId);

        // Resolve the approval status.
        approvalStatus = _approvalStatusOf({projectId: projectId, ruleset: ruleset});
    }

    /// @notice The ruleset that's up next for a project.
    /// @dev If an upcoming ruleset is not found for the project, returns an empty ruleset with all properties set to 0.
    /// @param projectId The ID of the project to get the upcoming ruleset of.
    /// @return ruleset The struct for the project's upcoming ruleset.
    function upcomingOf(uint256 projectId) external view override returns (JBRuleset memory ruleset) {
        // If the project does not have a latest ruleset, return an empty struct.
        // slither-disable-next-line incorrect-equality
        if (latestRulesetIdOf[projectId] == 0) return _getStructFor(0, 0);

        // Get a reference to the upcoming approvable ruleset's ID.
        uint256 upcomingApprovableRulesetId = _upcomingApprovableRulesetIdOf(projectId);

        // Keep a reference to its approval status.
        JBApprovalStatus approvalStatus;

        // If an upcoming approvable ruleset has been queued, and it's approval status is Approved or ApprovalExpected,
        // return its ruleset struct
        if (upcomingApprovableRulesetId != 0) {
            ruleset = _getStructFor(projectId, upcomingApprovableRulesetId);

            // Get a reference to the approval status.
            approvalStatus = _approvalStatusOf(projectId, ruleset);

            // If the approval hook is empty, expects approval, or has approved the ruleset, return it.
            if (
                // slither-disable-next-line incorrect-equality
                approvalStatus == JBApprovalStatus.Approved || approvalStatus == JBApprovalStatus.ApprovalExpected
                    || approvalStatus == JBApprovalStatus.Empty
            ) return ruleset;

            // Resolve the ruleset for the ruleset the upcoming approvable ruleset was based on.
            ruleset = _getStructFor(projectId, ruleset.basedOnId);
        } else {
            // Resolve the ruleset for the latest queued ruleset.
            ruleset = _getStructFor(projectId, latestRulesetIdOf[projectId]);

            // If the latest ruleset starts in the future, it must start in the distant future
            // Since its not the upcoming approvable ruleset. In this case, base the upcoming ruleset on the base
            // ruleset.
            while (ruleset.start > block.timestamp) {
                ruleset = _getStructFor(projectId, ruleset.basedOnId);
            }
        }

        // There's no queued if the current has a duration of 0.
        // slither-disable-next-line incorrect-equality
        if (ruleset.duration == 0) return _getStructFor(0, 0);

        // Get a reference to the approval status.
        approvalStatus = _approvalStatusOf(projectId, ruleset);

        // Check to see if this ruleset's approval hook hasn't failed.
        // If so, return a ruleset based on it.
        // slither-disable-next-line incorrect-equality
        if (approvalStatus == JBApprovalStatus.Approved || approvalStatus == JBApprovalStatus.Empty) {
            return _simulateCycledRulesetBasedOn({projectId: projectId, baseRuleset: ruleset, allowMidRuleset: false});
        }

        // Get the ruleset of its base ruleset, which carries the last approved configuration.
        ruleset = _getStructFor(projectId, ruleset.basedOnId);

        // There's no queued if the base, which must still be the current, has a duration of 0.
        // slither-disable-next-line incorrect-equality
        if (ruleset.duration == 0) return _getStructFor(0, 0);

        // Return a simulated cycled ruleset.
        return _simulateCycledRulesetBasedOn({projectId: projectId, baseRuleset: ruleset, allowMidRuleset: false});
    }

    //*********************************************************************//
    // --------------------------- public views -------------------------- //
    //*********************************************************************//

    /// @notice The cycle number of the next ruleset given the specified ruleset.
    /// @dev Each time a ruleset starts, whether it was queued or cycled over, the cycle number is incremented by 1.
    /// @param baseRulesetCycleNumber The cycle number of the base ruleset.
    /// @param baseRulesetStart The start time of the base ruleset.
    /// @param baseRulesetDuration The duration of the base ruleset.
    /// @param start The start time of the ruleset to derive a cycle number for.
    /// @return The ruleset's cycle number.
    function deriveCycleNumberFrom(
        uint256 baseRulesetCycleNumber,
        uint256 baseRulesetStart,
        uint256 baseRulesetDuration,
        uint256 start
    )
        public
        pure
        returns (uint256)
    {
        // A subsequent ruleset to one with a duration of 0 should be the next number.
        // slither-disable-next-line incorrect-equality
        if (baseRulesetDuration == 0) {
            return baseRulesetCycleNumber + 1;
        }

        // The difference between the start of the base ruleset and the proposed start.
        uint256 startDistance = start - baseRulesetStart;

        // Find the number of base rulesets that fit in the start distance.
        return baseRulesetCycleNumber + (startDistance / baseRulesetDuration);
    }

    /// @notice The date that is the nearest multiple of the base ruleset's duration from the start of the next cycle.
    /// @param baseRulesetStart The start time of the base ruleset.
    /// @param baseRulesetDuration The duration of the base ruleset.
    /// @param mustStartAtOrAfter The earliest time the next ruleset can start. The ruleset cannot start before this
    /// timestamp.
    /// @return start The next start time.
    function deriveStartFrom(
        uint256 baseRulesetStart,
        uint256 baseRulesetDuration,
        uint256 mustStartAtOrAfter
    )
        public
        pure
        returns (uint256 start)
    {
        // A subsequent ruleset to one with a duration of 0 should start as soon as possible.
        // slither-disable-next-line incorrect-equality
        if (baseRulesetDuration == 0) return mustStartAtOrAfter;

        // The time when the ruleset immediately after the specified ruleset starts.
        uint256 nextImmediateStart = baseRulesetStart + baseRulesetDuration;

        // If the next immediate start is now or in the future, return it.
        if (nextImmediateStart >= mustStartAtOrAfter) {
            return nextImmediateStart;
        }

        // The amount of seconds since the `mustStartAtOrAfter` time which results in a start time that might satisfy
        // the specified limits.
        // slither-disable-next-line weak-prng
        uint256 timeFromImmediateStartMultiple = (mustStartAtOrAfter - nextImmediateStart) % baseRulesetDuration;

        // A reference to the first possible start timestamp.
        start = mustStartAtOrAfter - timeFromImmediateStartMultiple;

        // Add increments of duration as necessary to satisfy the threshold.
        while (mustStartAtOrAfter > start) {
            start += baseRulesetDuration;
        }
    }

    /// @notice The accumulated weight change since the specified ruleset.
    /// @param projectId The ID of the project to which the ruleset weights apply.
    /// @param baseRulesetStart The start time of the base ruleset.
    /// @param baseRulesetDuration The duration of the base ruleset.
    /// @param baseRulesetWeight The weight of the base ruleset.
    /// @param baseRulesetWeightCutPercent The weight cut percent of the base ruleset.
    /// @param baseRulesetCacheId The ID of the ruleset to base the calculation on (the previous ruleset).
    /// @param start The start time of the ruleset to derive a weight for.
    /// @return weight The derived weight, as a fixed point number with 18 decimals.
    function deriveWeightFrom(
        uint256 projectId,
        uint256 baseRulesetStart,
        uint256 baseRulesetDuration,
        uint256 baseRulesetWeight,
        uint256 baseRulesetWeightCutPercent,
        uint256 baseRulesetCacheId,
        uint256 start
    )
        public
        view
        returns (uint256 weight)
    {
        // A subsequent ruleset to one with a duration of 0 should have the next possible weight.
        // slither-disable-next-line incorrect-equality
        if (baseRulesetDuration == 0) {
            return mulDiv(
                baseRulesetWeight,
                JBConstants.MAX_WEIGHT_CUT_PERCENT - baseRulesetWeightCutPercent,
                JBConstants.MAX_WEIGHT_CUT_PERCENT
            );
        }

        // The weight should be based off the base ruleset's weight.
        weight = baseRulesetWeight;

        // If the weight cut percent is 0, the weight doesn't change.
        // slither-disable-next-line incorrect-equality
        if (baseRulesetWeightCutPercent == 0) return weight;

        // The difference between the start of the base ruleset and the proposed start.
        uint256 startDistance = start - baseRulesetStart;

        // Apply the base ruleset's weight cut percent for each ruleset that has passed.
        uint256 weightCutMultiple;
        unchecked {
            weightCutMultiple = startDistance / baseRulesetDuration; // Non-null duration is excluded above
        }

        // Check the cache if needed.
        if (baseRulesetCacheId > 0 && weightCutMultiple > _WEIGHT_CUT_MULTIPLE_CACHE_LOOKUP_THRESHOLD) {
            // Get a cached weight for the rulesetId.
            JBRulesetWeightCache memory cache = _weightCacheOf[projectId][baseRulesetCacheId];

            // If a cached value is available, use it.
            if (cache.weightCutMultiple > 0) {
                // Set the starting weight to be the cached value.
                weight = cache.weight;

                // Set the weight cut multiple to be the difference between the cached value and the total weight cut
                // multiple that should be applied.
                weightCutMultiple -= cache.weightCutMultiple;
            }
        }

        for (uint256 i; i < weightCutMultiple; i++) {
            // The number of times to apply the weight cut percent.
            // Base the new weight on the specified ruleset's weight.
            weight = mulDiv(
                weight,
                JBConstants.MAX_WEIGHT_CUT_PERCENT - baseRulesetWeightCutPercent,
                JBConstants.MAX_WEIGHT_CUT_PERCENT
            );

            // The calculation doesn't need to continue if the weight is 0.
            if (weight == 0) break;
        }
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice The approval status of a given ruleset for a given project ID.
    /// @param projectId The ID of the project the ruleset belongs to.
    /// @param ruleset The ruleset to get the approval status of.
    /// @return The approval status of the project.
    function _approvalStatusOf(uint256 projectId, JBRuleset memory ruleset) internal view returns (JBApprovalStatus) {
        // If there is no ruleset ID to check the approval hook of, the approval hook is empty.
        // slither-disable-next-line incorrect-equality
        if (ruleset.basedOnId == 0) return JBApprovalStatus.Empty;

        // Get the struct of the ruleset with the approval hook.
        JBRuleset memory approvalHookRuleset = _getStructFor(projectId, ruleset.basedOnId);

        // If there is no approval hook, it's considered empty.
        if (approvalHookRuleset.approvalHook == IJBRulesetApprovalHook(address(0))) {
            return JBApprovalStatus.Empty;
        }

        // Return the approval hook's approval status.
        // slither-disable-next-line calls-loop
        return approvalHookRuleset.approvalHook.approvalStatusOf(projectId, ruleset);
    }

    /// @notice The ID of the ruleset which has started and hasn't expired yet, whether or not it has been approved, for
    /// a given project. If approved, this is the active ruleset.
    /// @dev A value of 0 is returned if no ruleset was found.
    /// @dev Assumes the project has a latest ruleset.
    /// @param projectId The ID of the project to check for a currently approvable ruleset.
    /// @return The ID of a currently approvable ruleset if one exists, or 0 if one doesn't exist.
    function _currentlyApprovableRulesetIdOf(uint256 projectId) internal view returns (uint256) {
        // Get a reference to the project's latest ruleset.
        uint256 rulesetId = latestRulesetIdOf[projectId];

        // Get the struct for the latest ruleset.
        JBRuleset memory ruleset = _getStructFor(projectId, rulesetId);

        // Loop through all most recently queued rulesets until an approvable one is found, or we've proven one can't
        // exist.
        do {
            // If the latest ruleset is expired, return an empty ruleset.
            // A ruleset with a duration of 0 cannot expire.
            if (ruleset.duration != 0 && block.timestamp >= ruleset.start + ruleset.duration) {
                return 0;
            }

            // Return the ruleset's `rulesetId` if it has started.
            if (block.timestamp >= ruleset.start) {
                return ruleset.id;
            }

            ruleset = _getStructFor(projectId, ruleset.basedOnId);
        } while (ruleset.cycleNumber != 0);

        return 0;
    }

    /// @notice Unpack a ruleset's packed stored values into an easy-to-work-with ruleset struct.
    /// @param projectId The ID of the project the ruleset belongs to.
    /// @param rulesetId The ID of the ruleset to get the full struct for.
    /// @return ruleset A ruleset struct.
    function _getStructFor(uint256 projectId, uint256 rulesetId) internal view returns (JBRuleset memory ruleset) {
        // Return an empty ruleset if the specified `rulesetId` is 0.
        // slither-disable-next-line incorrect-equality
        if (rulesetId == 0) return ruleset;

        ruleset.id = uint48(rulesetId);

        uint256 packedIntrinsicProperties = _packedIntrinsicPropertiesOf[projectId][rulesetId];

        // `weight` in bits 0-111 bits.
        ruleset.weight = uint112(packedIntrinsicProperties);
        // `basedOnId` in bits 112-159 bits.
        ruleset.basedOnId = uint48(packedIntrinsicProperties >> 112);
        // `start` in bits 160-207 bits.
        ruleset.start = uint48(packedIntrinsicProperties >> 160);
        // `cycleNumber` in bits 208-255 bits.
        ruleset.cycleNumber = uint48(packedIntrinsicProperties >> 208);

        uint256 packedUserProperties = _packedUserPropertiesOf[projectId][rulesetId];

        // approval hook in bits 0-159 bits.
        ruleset.approvalHook = IJBRulesetApprovalHook(address(uint160(packedUserProperties)));
        // `duration` in bits 160-191 bits.
        ruleset.duration = uint32(packedUserProperties >> 160);
        // weight cut percent in bits 192-223 bits.
        ruleset.weightCutPercent = uint32(packedUserProperties >> 192);

        ruleset.metadata = _metadataOf[projectId][rulesetId];
    }

    /// @notice A simulated view of the ruleset that would be created if the provided one cycled over (if the project
    /// doesn't queue a new ruleset).
    /// @dev Returns an empty ruleset if a ruleset can't be simulated based on the provided one.
    /// @dev Assumes a simulated ruleset will never be based on a ruleset with a duration of 0.
    /// @param projectId The ID of the project of the ruleset.
    /// @param baseRuleset The ruleset that the simulated ruleset should be based on.
    /// @param allowMidRuleset A flag indicating if the simulated ruleset is allowed to already be mid ruleset.
    /// @return A simulated ruleset struct: the next ruleset by default. This will be overwritten if a new ruleset is
    /// queued for the project.
    function _simulateCycledRulesetBasedOn(
        uint256 projectId,
        JBRuleset memory baseRuleset,
        bool allowMidRuleset
    )
        internal
        view
        returns (JBRuleset memory)
    {
        // Get the distance from the current time to the start of the next possible ruleset.
        // If the simulated ruleset must not yet have started, the start time of the simulated ruleset must be in the
        // future.
        uint256 mustStartAtOrAfter = !allowMidRuleset ? block.timestamp + 1 : block.timestamp - baseRuleset.duration + 1;

        // Calculate what the start time should be.
        uint256 start = deriveStartFrom({
            baseRulesetStart: baseRuleset.start,
            baseRulesetDuration: baseRuleset.duration,
            mustStartAtOrAfter: mustStartAtOrAfter
        });

        // Calculate what the cycle number should be.
        uint256 rulesetCycleNumber = deriveCycleNumberFrom({
            baseRulesetCycleNumber: baseRuleset.cycleNumber,
            baseRulesetStart: baseRuleset.start,
            baseRulesetDuration: baseRuleset.duration,
            start: start
        });

        return JBRuleset({
            cycleNumber: uint48(rulesetCycleNumber),
            id: baseRuleset.id,
            basedOnId: baseRuleset.basedOnId,
            start: uint48(start),
            duration: baseRuleset.duration,
            weight: uint112(
                deriveWeightFrom({
                    projectId: projectId,
                    baseRulesetStart: baseRuleset.start,
                    baseRulesetDuration: baseRuleset.duration,
                    baseRulesetWeight: baseRuleset.weight,
                    baseRulesetWeightCutPercent: baseRuleset.weightCutPercent,
                    baseRulesetCacheId: baseRuleset.id,
                    start: start
                })
            ),
            weightCutPercent: baseRuleset.weightCutPercent,
            approvalHook: baseRuleset.approvalHook,
            metadata: baseRuleset.metadata
        });
    }

    /// @notice The ruleset up next for a project, if one exists, whether or not that ruleset has been approved.
    /// @dev A value of 0 is returned if no ruleset was found.
    /// @dev Assumes the project has a `latestRulesetIdOf` value.
    /// @param projectId The ID of the project to check for an upcoming approvable ruleset.
    /// @return rulesetId The `rulesetId` of the upcoming approvable ruleset if one exists, or 0 if one doesn't exist.
    function _upcomingApprovableRulesetIdOf(uint256 projectId) internal view returns (uint256 rulesetId) {
        // Get a reference to the ID of the project's latest ruleset.
        rulesetId = latestRulesetIdOf[projectId];

        // Get the struct for the latest ruleset.
        JBRuleset memory ruleset = _getStructFor(projectId, rulesetId);

        // There is no upcoming ruleset if the latest ruleset has already started.
        // slither-disable-next-line incorrect-equality
        if (block.timestamp >= ruleset.start) return 0;

        // If this is the first ruleset, it is queued.
        // slither-disable-next-line incorrect-equality
        if (ruleset.cycleNumber == 1) return rulesetId;

        // Get a reference to the ID of the ruleset the latest ruleset was based on.
        uint256 basedOnId = ruleset.basedOnId;

        // Get the necessary properties for the base ruleset.
        JBRuleset memory baseRuleset;

        // Find the base ruleset that is not still queued.
        while (true) {
            baseRuleset = _getStructFor(projectId, basedOnId);

            // If the base ruleset starts in the future,
            if (block.timestamp < baseRuleset.start) {
                // Set the `rulesetId` to the one found.
                rulesetId = baseRuleset.id;
                // Check the ruleset it was based on in the next iteration.
                basedOnId = baseRuleset.basedOnId;
            } else {
                // Break out of the loop when a base ruleset which has already started is found.
                break;
            }
        }

        // Get the ruleset struct for the ID found.
        ruleset = _getStructFor(projectId, rulesetId);

        // If the latest ruleset doesn't start until after another base ruleset return 0.
        if (baseRuleset.duration != 0 && block.timestamp < ruleset.start - baseRuleset.duration) {
            return 0;
        }
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Queues the upcoming approvable ruleset for the specified project.
    /// @dev Only a project's current controller can queue its rulesets.
    /// @param projectId The ID of the project to queue the ruleset for.
    /// @param duration The number of seconds the ruleset lasts for, after which a new ruleset starts.
    /// - A `duration` of 0 means this ruleset will remain active until the project owner queues a new ruleset. That new
    /// ruleset will start immediately.
    /// - A ruleset with a non-zero `duration` applies until the duration ends – any newly queued rulesets will be
    /// *queued* to take effect afterwards.
    /// - If a duration ends and no new rulesets are queued, the ruleset rolls over to a new ruleset with the same rules
    /// (except for a new `start` timestamp and a cut `weight`).
    /// @param weight A fixed point number with 18 decimals that contracts can use to base arbitrary calculations on.
    /// Payment terminals generally use this to determine how many tokens should be minted when the project is paid.
    /// @param weightCutPercent A fraction (out of `JBConstants.MAX_WEIGHT_CUT_PERCENT`) to reduce the next ruleset's
    /// `weight`
    /// by.
    /// - If a ruleset specifies a non-zero `weight`, the `weightCutPercent` does not apply.
    /// - If the `weightCutPercent` is 0, the `weight` stays the same.
    /// - If the `weightCutPercent` is 10% of `JBConstants.MAX_WEIGHT_CUT_PERCENT`, next ruleset's `weight` will be 90%
    /// of the
    /// current
    /// one.
    /// @param approvalHook A contract which dictates whether a proposed ruleset should be accepted or rejected. It can
    /// be used to constrain a project owner's ability to change ruleset parameters over time.
    /// @param metadata Arbitrary extra data to associate with this ruleset. This metadata is not used by `JBRulesets`.
    /// @param mustStartAtOrAfter The earliest time the ruleset can start. The ruleset cannot start before this
    /// timestamp.
    /// @return The struct of the new ruleset.
    function queueFor(
        uint256 projectId,
        uint256 duration,
        uint256 weight,
        uint256 weightCutPercent,
        IJBRulesetApprovalHook approvalHook,
        uint256 metadata,
        uint256 mustStartAtOrAfter
    )
        external
        override
        onlyControllerOf(projectId)
        returns (JBRuleset memory)
    {
        // Duration must fit in a uint32.
        if (duration > type(uint32).max) revert JBRulesets_InvalidRulesetDuration(duration, type(uint32).max);

        // Weight cut percent must be less than or equal to 100%.
        if (weightCutPercent > JBConstants.MAX_WEIGHT_CUT_PERCENT) {
            revert JBRulesets_InvalidWeightCutPercent(weightCutPercent);
        }

        // Weight must fit into a uint112.
        if (weight > type(uint112).max) revert JBRulesets_InvalidWeight(weight, type(uint112).max);

        // If the start date is not set, set it to be the current timestamp.
        if (mustStartAtOrAfter == 0) {
            mustStartAtOrAfter = block.timestamp;
        }

        // Make sure the min start date fits in a uint48, and that the start date of the following ruleset will also fit
        // within the max.
        if (mustStartAtOrAfter + duration > type(uint48).max) {
            revert JBRulesets_InvalidRulesetEndTime(mustStartAtOrAfter + duration, type(uint48).max);
        }

        // Approval hook should be a valid contract, supporting the correct interface
        if (approvalHook != IJBRulesetApprovalHook(address(0))) {
            // Revert if there isn't a contract at the address
            if (address(approvalHook).code.length == 0) revert JBRulesets_InvalidRulesetApprovalHook(approvalHook);

            // Make sure the approval hook supports the expected interface.
            try approvalHook.supportsInterface(type(IJBRulesetApprovalHook).interfaceId) returns (bool doesSupport) {
                if (!doesSupport) revert JBRulesets_InvalidRulesetApprovalHook(approvalHook); // Contract exists at the
                    // address but
                    // with the
                    // wrong interface
            } catch {
                revert JBRulesets_InvalidRulesetApprovalHook(approvalHook); // No ERC165 support
            }
        }

        // Get a reference to the latest ruleset's ID.
        uint256 latestId = latestRulesetIdOf[projectId];

        // The new rulesetId timestamp is now, or an increment from now if the current timestamp is taken.
        uint256 rulesetId = latestId >= block.timestamp ? latestId + 1 : block.timestamp;

        // Set up the ruleset by configuring intrinsic properties.
        _configureIntrinsicPropertiesFor(projectId, rulesetId, weight, mustStartAtOrAfter);

        // Efficiently stores the ruleset's user-defined properties.
        // If all user config properties are zero, no need to store anything as the default value will have the same
        // outcome.
        if (approvalHook != IJBRulesetApprovalHook(address(0)) || duration > 0 || weightCutPercent > 0) {
            // approval hook in bits 0-159 bytes.
            uint256 packed = uint160(address(approvalHook));

            // duration in bits 160-191 bytes.
            packed |= duration << 160;

            // weightCutPercent in bits 192-223 bytes.
            packed |= weightCutPercent << 192;

            // Set in storage.
            _packedUserPropertiesOf[projectId][rulesetId] = packed;
        }

        // Set the metadata if needed.
        if (metadata > 0) _metadataOf[projectId][rulesetId] = metadata;

        emit RulesetQueued({
            rulesetId: rulesetId,
            projectId: projectId,
            duration: duration,
            weight: weight,
            weightCutPercent: weightCutPercent,
            approvalHook: approvalHook,
            metadata: metadata,
            mustStartAtOrAfter: mustStartAtOrAfter,
            caller: msg.sender
        });

        // Return the struct for the new ruleset's ID.
        return _getStructFor(projectId, rulesetId);
    }

    /// @notice Cache the value of the ruleset weight.
    /// @param projectId The ID of the project having its ruleset weight cached.
    function updateRulesetWeightCache(uint256 projectId) external override {
        // Keep a reference to the struct for the latest queued ruleset.
        // The cached value will be based on this struct.
        JBRuleset memory latestQueuedRuleset = _getStructFor(projectId, latestRulesetIdOf[projectId]);

        // Nothing to cache if the latest ruleset doesn't have a duration or a weight cut percent.
        // slither-disable-next-line incorrect-equality
        if (latestQueuedRuleset.duration == 0 || latestQueuedRuleset.weightCutPercent == 0) return;

        // Get a reference to the current cache.
        JBRulesetWeightCache storage cache = _weightCacheOf[projectId][latestQueuedRuleset.id];

        // Determine the largest start timestamp the cache can be filled to.
        uint256 maxStart = latestQueuedRuleset.start
            + (cache.weightCutMultiple + _MAX_WEIGHT_CUT_MULTIPLE_CACHE_THRESHOLD) * latestQueuedRuleset.duration;

        // Determine the start timestamp to derive a weight from for the cache.
        uint256 start = block.timestamp < maxStart ? block.timestamp : maxStart;

        // The difference between the start of the latest queued ruleset and the start of the ruleset we're caching the
        // weight of.
        uint256 startDistance = start - latestQueuedRuleset.start;

        // Calculate the weight cut multiple.
        uint168 weightCutMultiple;
        unchecked {
            weightCutMultiple = uint168(startDistance / latestQueuedRuleset.duration);
        }

        // Store the new values.
        cache.weight = uint112(
            deriveWeightFrom({
                projectId: projectId,
                baseRulesetStart: latestQueuedRuleset.start,
                baseRulesetDuration: latestQueuedRuleset.duration,
                baseRulesetWeight: latestQueuedRuleset.weight,
                baseRulesetWeightCutPercent: latestQueuedRuleset.weightCutPercent,
                baseRulesetCacheId: latestQueuedRuleset.id,
                start: start
            })
        );
        cache.weightCutMultiple = weightCutMultiple;

        emit WeightCacheUpdated({
            projectId: projectId,
            weight: cache.weight,
            weightCutMultiple: weightCutMultiple,
            caller: msg.sender
        });
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Updates the latest ruleset for this project if it exists. If there is no ruleset, initializes one.
    /// @param projectId The ID of the project to update the latest ruleset for.
    /// @param rulesetId The timestamp of when the ruleset was queued.
    /// @param weight The weight to store in the queued ruleset.
    /// @param mustStartAtOrAfter The earliest time the ruleset can start. The ruleset cannot start before this
    /// timestamp.
    function _configureIntrinsicPropertiesFor(
        uint256 projectId,
        uint256 rulesetId,
        uint256 weight,
        uint256 mustStartAtOrAfter
    )
        internal
    {
        // Keep a reference to the project's latest ruleset's ID.
        uint256 latestId = latestRulesetIdOf[projectId];

        // If the project doesn't have a ruleset yet, initialize one.
        // slither-disable-next-line incorrect-equality
        if (latestId == 0) {
            // Use an empty ruleset as the base.
            return _initializeRulesetFor({
                projectId: projectId,
                baseRuleset: _getStructFor(0, 0),
                rulesetId: rulesetId,
                mustStartAtOrAfter: mustStartAtOrAfter,
                weight: weight
            });
        }

        // Get a reference to the latest ruleset's struct.
        JBRuleset memory baseRuleset = _getStructFor(projectId, latestId);

        // Get a reference to the approval status.
        JBApprovalStatus approvalStatus = _approvalStatusOf(projectId, baseRuleset);

        // If the base ruleset has started but wasn't approved if a approval hook exists
        // OR it hasn't started but is currently approved
        // OR it hasn't started but it is likely to be approved and takes place before the proposed one,
        // set the struct to be the ruleset it's based on, which carries the latest approved ruleset.
        if (
            (
                block.timestamp >= baseRuleset.start && approvalStatus != JBApprovalStatus.Approved
                    && approvalStatus != JBApprovalStatus.Empty
            )
                || (
                    block.timestamp < baseRuleset.start && mustStartAtOrAfter < baseRuleset.start + baseRuleset.duration
                        && approvalStatus != JBApprovalStatus.Approved
                )
                || (
                    block.timestamp < baseRuleset.start && mustStartAtOrAfter >= baseRuleset.start + baseRuleset.duration
                        && approvalStatus != JBApprovalStatus.Approved && approvalStatus != JBApprovalStatus.ApprovalExpected
                        && approvalStatus != JBApprovalStatus.Empty
                )
        ) {
            baseRuleset = _getStructFor(projectId, baseRuleset.basedOnId);
        }

        // The time when the duration of the base ruleset's approval hook has finished.
        // If the provided ruleset has no approval hook, return 0 (no constraint on start time).
        uint256 timestampAfterApprovalHook = baseRuleset.approvalHook == IJBRulesetApprovalHook(address(0))
            ? 0
            : rulesetId + baseRuleset.approvalHook.DURATION();

        _initializeRulesetFor({
            projectId: projectId,
            baseRuleset: baseRuleset,
            rulesetId: rulesetId,
            // Can only start after the approval hook.
            mustStartAtOrAfter: timestampAfterApprovalHook > mustStartAtOrAfter
                ? timestampAfterApprovalHook
                : mustStartAtOrAfter,
            weight: weight
        });
    }

    /// @notice Initializes a ruleset with the specified properties.
    /// @param projectId The ID of the project to initialize the ruleset for.
    /// @param baseRuleset The ruleset struct to base the newly initialized one on.
    /// @param rulesetId The `rulesetId` for the ruleset being initialized.
    /// @param mustStartAtOrAfter The earliest time the ruleset can start. The ruleset cannot start before this
    /// timestamp.
    /// @param weight The weight to give the newly initialized ruleset.
    function _initializeRulesetFor(
        uint256 projectId,
        JBRuleset memory baseRuleset,
        uint256 rulesetId,
        uint256 mustStartAtOrAfter,
        uint256 weight
    )
        internal
    {
        // If there is no base, initialize a first ruleset.
        // slither-disable-next-line incorrect-equality
        if (baseRuleset.cycleNumber == 0) {
            // Set fresh intrinsic properties.
            _packAndStoreIntrinsicPropertiesOf({
                rulesetId: rulesetId,
                projectId: projectId,
                rulesetCycleNumber: 1,
                weight: weight,
                basedOnId: baseRuleset.id,
                start: mustStartAtOrAfter
            });
        } else {
            // Derive the correct next start time from the base.
            uint256 start = deriveStartFrom({
                baseRulesetStart: baseRuleset.start,
                baseRulesetDuration: baseRuleset.duration,
                mustStartAtOrAfter: mustStartAtOrAfter
            });

            // A weight of 1 is a special case that represents inheriting the cut weight of the previous
            // ruleset.
            weight = weight == 1
                ? deriveWeightFrom({
                    projectId: projectId,
                    baseRulesetStart: baseRuleset.start,
                    baseRulesetDuration: baseRuleset.duration,
                    baseRulesetWeight: baseRuleset.weight,
                    baseRulesetWeightCutPercent: baseRuleset.weightCutPercent,
                    baseRulesetCacheId: baseRuleset.id,
                    start: start
                })
                : weight;

            // Derive the correct ruleset cycle number.
            uint256 rulesetCycleNumber = deriveCycleNumberFrom({
                baseRulesetCycleNumber: baseRuleset.cycleNumber,
                baseRulesetStart: baseRuleset.start,
                baseRulesetDuration: baseRuleset.duration,
                start: start
            });

            // Update the intrinsic properties.
            _packAndStoreIntrinsicPropertiesOf({
                rulesetId: rulesetId,
                projectId: projectId,
                rulesetCycleNumber: rulesetCycleNumber,
                weight: weight,
                basedOnId: baseRuleset.id,
                start: start
            });
        }

        // Set the project's latest ruleset configuration.
        latestRulesetIdOf[projectId] = rulesetId;

        emit RulesetInitialized({
            rulesetId: rulesetId,
            projectId: projectId,
            basedOnId: baseRuleset.id,
            caller: msg.sender
        });
    }

    /// @notice Efficiently stores the provided intrinsic properties of a ruleset.
    /// @param rulesetId The `rulesetId` of the ruleset to pack and store for.
    /// @param projectId The ID of the project the ruleset belongs to.
    /// @param rulesetCycleNumber The cycle number of the ruleset.
    /// @param weight The weight of the ruleset.
    /// @param basedOnId The `rulesetId` of the ruleset this ruleset was based on.
    /// @param start The start time of this ruleset.
    function _packAndStoreIntrinsicPropertiesOf(
        uint256 rulesetId,
        uint256 projectId,
        uint256 rulesetCycleNumber,
        uint256 weight,
        uint256 basedOnId,
        uint256 start
    )
        internal
    {
        // `weight` in bits 0-111.
        uint256 packed = weight;

        // `basedOnId` in bits 112-159.
        packed |= basedOnId << 112;

        // `start` in bits 160-207.
        packed |= start << 160;

        // cycle number in bits 208-255.
        packed |= rulesetCycleNumber << 208;

        // Store the packed value.
        _packedIntrinsicPropertiesOf[projectId][rulesetId] = packed;
    }
}
