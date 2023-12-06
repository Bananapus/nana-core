// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {JBControlled} from "./abstract/JBControlled.sol";
import {JBApprovalStatus} from "./enums/JBApprovalStatus.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBRulesetApprovalHook} from "./interfaces/IJBRulesetApprovalHook.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";
import {JBRulesetData} from "./structs/JBRulesetData.sol";
import {JBRulesetWeightCache} from "./structs/JBRulesetWeightCache.sol";

/// @notice Manages rulesets and queuing.
/// @dev Rulesets dictate how a project behaves for a period of time. To learn more about their functionality, see the `JBRuleset` data structure.
/// @dev Throughout this contract, `rulesetId` is an identifier for each ruleset. The `rulesetId` is the unix timestamp when the ruleset was initialized.
/// @dev `approvable` means a ruleset which may or may not be approved.
contract JBRulesets is JBControlled, IJBRulesets {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error INVALID_RULESET_APPROVAL_HOOK();
    error INVALID_DECAY_RATE();
    error INVALID_RULESET_DURATION();
    error INVALID_RULESET_END_TIME();
    error INVALID_WEIGHT();
    error BLOCK_ALREADY_CONTAINS_RULESET();

    //*********************************************************************//
    // ------------------------- private constants ----------------------- //
    //*********************************************************************//

    /// @notice The maximum number of decay rate multiples that can be cached at a time.
    uint256 private constant _MAX_DECAY_MULTIPLE_CACHE_THRESHOLD = 50_000;

    /// @notice The number of decay rate multiples before a cached value is sought.
    uint256 private constant _DECAY_MULTIPLE_CACHE_LOOKUP_THRESHOLD = 1000;

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    /// @notice The user-defined properties of each ruleset, packed into one storage slot.
    /// @custom:param _projectId The ID of the project to get the user-defined properties of.
    /// @custom:param _rulesetId The ID of the ruleset to get the user-defined properties of.
    mapping(uint256 => mapping(uint256 => uint256)) private _packedUserPropertiesOf;

    /// @notice The mechanism-added properties to manage and schedule each ruleset, packed into one storage slot.
    /// @custom:param _projectId The ID of the project to get the intrinsic properties of.
    /// @custom:param _rulesetId The ID of the ruleset to get the intrinsic properties of.
    mapping(uint256 => mapping(uint256 => uint256)) private _packedIntrinsicPropertiesOf;

    /// @notice The metadata for each ruleset, packed into one storage slot.
    /// @custom:param _projectId The ID of the project to get metadata of.
    /// @custom:param _rulesetId The ID of the ruleset to get metadata of.
    mapping(uint256 => mapping(uint256 => uint256)) private _metadataOf;

    /// @notice Cached weight values to derive rulesets from.
    /// @custom:param _projectId The ID of the project to which the cache applies.
    mapping(uint256 => JBRulesetWeightCache) internal _weightCacheOf;
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The ID of the ruleset with the latest start time for a specific project, whether the ruleset has been approved or not.
    /// @dev If a project has multiple rulesets queued, the `latestRulesetIdOf` will be the last one. This is the "changeable" cycle.
    /// @custom:param _projectId The ID of the project to get the latest ruleset ID of.
    /// @return latestRulesetIdOf The `rulesetId` of the project's latest ruleset.
    mapping(uint256 => uint256) public override latestRulesetIdOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Get the ruleset struct for a given `rulesetId` and `projectId`.
    /// @param _projectId The ID of the project to which the ruleset belongs.
    /// @param _rulesetId The ID of the ruleset to get the struct of.
    /// @return ruleset The ruleset struct.
    function getRulesetOf(uint256 _projectId, uint256 _rulesetId)
        external
        view
        override
        returns (JBRuleset memory ruleset)
    {
        return _getStructFor(_projectId, _rulesetId);
    }

    /// @notice The latest ruleset queued for a project. Returns the ruleset's struct and its current approval status.
    /// @dev Returns struct and status for the ruleset initialized furthest in the future (at the end of the rulset queue).
    /// @param _projectId The ID of the project to get the latest queued ruleset of.
    /// @return ruleset The project's latest queued ruleset's struct.
    /// @return approvalStatus The approval hook's status for the ruleset.
    function latestQueuedRulesetOf(uint256 _projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBApprovalStatus approvalStatus)
    {
        // Get a reference to the latest ruleset's ID.
        uint256 _rulesetId = latestRulesetIdOf[_projectId];

        // Resolve the struct for the latest ruleset.
        ruleset = _getStructFor(_projectId, _rulesetId);

        // Resolve the approval status.
        approvalStatus = _approvalStatusOf(_projectId, ruleset.id, ruleset.start, ruleset.basedOnId);
    }

    /// @notice The ruleset that's up next for a project.
    /// @dev If an upcoming ruleset is not found for the project, returns an empty ruleset with all properties set to 0.
    /// @param _projectId The ID of the project to get the upcoming ruleset of.
    /// @return ruleset The struct for the project's upcoming ruleset.
    function upcomingRulesetOf(uint256 _projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset)
    {
        // If the project does not have a latest ruleset, return an empty struct.
        if (latestRulesetIdOf[_projectId] == 0) return _getStructFor(0, 0);

        // Get a reference to the upcoming approvable ruleset's ID.
        uint256 _upcomingApprovableRulesetId = _upcomingApprovableRulesetIdOf(_projectId);

        // Keep a reference to its approval status.
        JBApprovalStatus _approvalStatus;

        // If an upcoming approvable ruleset has been queued, and it's approval status is Approved or ApprovalExpected, return its ruleset struct
        if (_upcomingApprovableRulesetId != 0) {
            ruleset = _getStructFor(_projectId, _upcomingApprovableRulesetId);

            // Get a reference to the approval status.
            _approvalStatus = _approvalStatusOf(_projectId, ruleset);

            // If the approval hook is empty, expects approval, or has approved the ruleset, return it.
            if (
                _approvalStatus == JBApprovalStatus.Approved
                    || _approvalStatus == JBApprovalStatus.ApprovalExpected
                    || _approvalStatus == JBApprovalStatus.Empty
            ) return ruleset;

            // Resolve the ruleset for the ruleset the upcoming approvable ruleset was based on.
            ruleset = _getStructFor(_projectId, ruleset.basedOnId);
        } else {
            // Resolve the ruleset for the latest queued ruleset.
            ruleset = _getStructFor(_projectId, latestRulesetIdOf[_projectId]);

            // If the latest ruleset starts in the future, it must start in the distant future
            // Since its not the upcoming approvable ruleset. In this case, base the upcoming ruleset on the base ruleset.
            while (ruleset.start > block.timestamp) {
                ruleset = _getStructFor(_projectId, ruleset.basedOnId);
            }
        }

        // There's no queued if the current has a duration of 0.
        if (ruleset.duration == 0) return _getStructFor(0, 0);

        // Get a reference to the approval status.
        _approvalStatus = _approvalStatusOf(_projectId, ruleset);

        // Check to see if this ruleset's approval hook hasn't failed.
        // If so, return a ruleset based on it.
        if (
            _approvalStatus == JBApprovalStatus.Approved
                || _approvalStatus == JBApprovalStatus.Empty
        ) return _simulateCycledRulesetBasedOn(ruleset, false);

        // Get the ruleset of its base ruleset, which carries the last approved configuration.
        ruleset = _getStructFor(_projectId, ruleset.basedOnId);

        // There's no queued if the base, which must still be the current, has a duration of 0.
        if (ruleset.duration == 0) return _getStructFor(0, 0);

        // Return a simulated cycled ruleset.
        return _simulateCycledRulesetBasedOn(ruleset, false);
    }

    /// @notice The ruleset that is currently active for the specified project.
    /// @dev If a current ruleset of the project is not found, returns an empty ruleset with all properties set to 0.
    /// @param _projectId The ID of the project to get the current ruleset of.
    /// @return ruleset The project's current ruleset.
    function currentOf(uint256 _projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset)
    {
        // If the project does not have a ruleset, return an empty struct.
        if (latestRulesetIdOf[_projectId] == 0) return _getStructFor(0, 0);

        // Get a reference to the currently approvable ruleset's ID.
        uint256 _rulesetId = _currentlyApprovableRulesetIdOf(_projectId);

        // Keep a reference to the currently approvable ruleset's struct.
        JBRuleset memory _ruleset;

        // If a currently approvable ruleset exists...
        if (_rulesetId != 0) {
            // Resolve the struct for the currently approvable ruleset.
            _ruleset = _getStructFor(_projectId, _rulesetId);

            // Get a reference to the approval status.
            JBApprovalStatus _approvalStatus = _approvalStatusOf(_projectId, _ruleset);

            // Check to see if this ruleset's approval hook is approved if it exists.
            // If so, return it.
            if (
                _approvalStatus == JBApprovalStatus.Approved
                    || _approvalStatus == JBApprovalStatus.Empty
            ) return _ruleset;

            // If it hasn't been approved, set the ruleset configuration to be the configuration of the ruleset that it's based on,
            // which carries the last approved configuration.
            _rulesetId = _ruleset.basedOnId;

            // Keep a reference to its ruleset.
            _ruleset = _getStructFor(_projectId, _rulesetId);
        } else {
            // No upcoming ruleset found that is currently approvable,
            // so use the latest ruleset ID.
            _rulesetId = latestRulesetIdOf[_projectId];

            // Get the struct for the latest ID.
            _ruleset = _getStructFor(_projectId, _rulesetId);

            // Get a reference to the approval status.
            JBApprovalStatus _approvalStatus = _approvalStatusOf(_projectId, _ruleset);

            // While the ruleset has a approval hook that isn't approved or if it hasn't yet started, get a reference to the ruleset that the latest is based on, which has the latest approved configuration.
            while (
                (
                    _approvalStatus != JBApprovalStatus.Approved
                        && _approvalStatus != JBApprovalStatus.Empty
                ) || block.timestamp < _ruleset.start
            ) {
                _rulesetId = _ruleset.basedOnId;
                _ruleset = _getStructFor(_projectId, _rulesetId);
                _approvalStatus = _approvalStatusOf(_projectId, _ruleset);
            }
        }

        // If the base has no duration, it's still the current one.
        if (_ruleset.duration == 0) return _ruleset;

        // Return a simulation of the current ruleset.
        return _simulateCycledRulesetBasedOn(_ruleset, true);
    }

    /// @notice The current approval status of a given project's latest ruleset.
    /// @param _projectId The ID of the project to check the approval status of.
    /// @return The project's current approval status.
    function currentApprovalStatusForLatestRulesetOf(uint256 _projectId)
        external
        view
        override
        returns (JBApprovalStatus)
    {
        // Get a reference to the latest ruleset ID.
        uint256 _rulesetId = latestRulesetIdOf[_projectId];

        // Resolve the struct for the latest ruleset.
        JBRuleset memory _ruleset = _getStructFor(_projectId, _rulesetId);

        return _approvalStatusOf(_projectId, _ruleset.id, _ruleset.start, _ruleset.basedOnId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _directory A contract storing directories of terminals and controllers for each project.
    // solhint-disable-next-line no-empty-blocks
    constructor(IJBDirectory _directory) JBControlled(_directory) {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Queues the upcoming approvable ruleset for the specified project.
    /// @dev Only a project's current controller can queue its rulesets.
    /// @param _projectId The ID of the project the ruleset is being queued for.
    /// @param _data The ruleset's user-defined data.
    /// @param _metadata Arbitrary extra data to associate with this ruleset. This metadata is not used by `JBRulesets`.
    /// @param _mustStartAtOrAfter The earliest time the ruleset can start. The ruleset cannot start before this timestamp.
    /// @return The struct of the new ruleset.
    function queueFor(
        uint256 _projectId,
        JBRulesetData calldata _data,
        uint256 _metadata,
        uint256 _mustStartAtOrAfter
    ) external override onlyController(_projectId) returns (JBRuleset memory) {
        // Duration must fit in a uint32.
        if (_data.duration > type(uint32).max) revert INVALID_RULESET_DURATION();

        // Decay rate must be less than or equal to 100%.
        if (_data.decayRate > JBConstants.MAX_DECAY_RATE) {
            revert INVALID_DECAY_RATE();
        }

        // Weight must fit into a uint88.
        if (_data.weight > type(uint88).max) revert INVALID_WEIGHT();

        // If the start date is in the past, set it to be the current timestamp.
        if (_mustStartAtOrAfter < block.timestamp) {
            _mustStartAtOrAfter = block.timestamp;
        }

        // Make sure the min start date fits in a uint56, and that the start date of the following ruleset will also fit within the max.
        if (_mustStartAtOrAfter + _data.duration > type(uint56).max) {
            revert INVALID_RULESET_END_TIME();
        }

        // Approval hook should be a valid contract, supporting the correct interface
        if (_data.hook != IJBRulesetApprovalHook(address(0))) {
            address _approvalHook = address(_data.hook);

            // Revert if there isn't a contract at the address
            if (_approvalHook.code.length == 0) revert INVALID_RULESET_APPROVAL_HOOK();

            // Make sure the approval hook supports the expected interface.
            try _data.hook.supportsInterface(type(IJBRulesetApprovalHook).interfaceId) returns (
                bool _supports
            ) {
                if (!_supports) revert INVALID_RULESET_APPROVAL_HOOK(); // Contract exists at the address but with the wrong interface
            } catch {
                revert INVALID_RULESET_APPROVAL_HOOK(); // No ERC165 support
            }
        }

        // Get a reference to the latest ruleset's ID.
        uint256 _latestId = latestRulesetIdOf[_projectId];

        // The new rulesetId timestamp is now, or an increment from now if the current timestamp is taken.
        uint256 _rulesetId = _latestId >= block.timestamp ? _latestId + 1 : block.timestamp;

        // Set up the ruleset by configuring intrinsic properties.
        _configureIntrinsicPropertiesFor(_projectId, _rulesetId, _data.weight, _mustStartAtOrAfter);

        // Efficiently stores the ruleset's user-defined properties.
        // If all user config properties are zero, no need to store anything as the default value will have the same outcome.
        if (
            _data.hook != IJBRulesetApprovalHook(address(0)) || _data.duration > 0
                || _data.decayRate > 0
        ) {
            // approval hook in bits 0-159 bytes.
            uint256 packed = uint160(address(_data.hook));

            // duration in bits 160-191 bytes.
            packed |= _data.duration << 160;

            // decayRate in bits 192-223 bytes.
            packed |= _data.decayRate << 192;

            // Set in storage.
            _packedUserPropertiesOf[_projectId][_rulesetId] = packed;
        }

        // Set the metadata if needed.
        if (_metadata > 0) _metadataOf[_projectId][_rulesetId] = _metadata;

        emit RulesetQueued(
            _rulesetId, _projectId, _data, _metadata, _mustStartAtOrAfter, msg.sender
        );

        // Return the struct for the new ruleset's ID.
        return _getStructFor(_projectId, _rulesetId);
    }

    /// @notice Cache the value of the ruleset weight.
    /// @param _projectId The ID of the project having its ruleset weight cached.
    function updateRulesetWeightCache(uint256 _projectId) external override {
        // Keep a reference to the struct for the latest queued ruleset.
        // The cached value will be based on this struct.
        JBRuleset memory _latestQueuedRuleset =
            _getStructFor(_projectId, latestRulesetIdOf[_projectId]);

        // Nothing to cache if the latest ruleset doesn't have a duration or a decay rate.
        if (_latestQueuedRuleset.duration == 0 || _latestQueuedRuleset.decayRate == 0) return;

        // Get a reference to the current cache.
        JBRulesetWeightCache storage _cache = _weightCacheOf[_latestQueuedRuleset.id];

        // Determine the largest start timestamp the cache can be filled to.
        uint256 _maxStart = _latestQueuedRuleset.start
            + (_cache.decayMultiple + _MAX_DECAY_MULTIPLE_CACHE_THRESHOLD)
                * _latestQueuedRuleset.duration;

        // Determine the start timestamp to derive a weight from for the cache.
        uint256 _start = block.timestamp < _maxStart ? block.timestamp : _maxStart;

        // The difference between the start of the latest queued ruleset and the start of the ruleset we're caching the weight of.
        uint256 _startDistance = _start - _latestQueuedRuleset.start;

        // Calculate the decay multiple.
        uint256 _decayMultiple;
        unchecked {
            _decayMultiple = _startDistance / _latestQueuedRuleset.duration;
        }

        // Store the new values.
        _cache.weight = _deriveWeightFrom(_latestQueuedRuleset, _start);
        _cache.decayMultiple = _decayMultiple;
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice Updates the latest ruleset for this project if it exists. If there is no ruleset, initializes one.
    /// @param _projectId The ID of the project to update the latest ruleset for.
    /// @param _rulesetId The timestamp of when the ruleset was queued.
    /// @param _weight The weight to store in the queued ruleset.
    /// @param _mustStartAtOrAfter The earliest time the ruleset can start. The ruleset cannot start before this timestamp.
    function _configureIntrinsicPropertiesFor(
        uint256 _projectId,
        uint256 _rulesetId,
        uint256 _weight,
        uint256 _mustStartAtOrAfter
    ) private {
        // Keep a reference to the project's latest ruleset's ID.
        uint256 _latestId = latestRulesetIdOf[_projectId];

        // If the project doesn't have a ruleset yet, initialize one.
        if (_latestId == 0) {
            // Use an empty ruleset as the base.
            return _initializeRulesetFor(
                _projectId, _getStructFor(0, 0), _rulesetId, _mustStartAtOrAfter, _weight
            );
        }

        // Get a reference to the latest ruleset's struct.
        JBRuleset memory _baseRuleset = _getStructFor(_projectId, _latestId);

        // Get a reference to the approval status.
        JBApprovalStatus _approvalStatus = _approvalStatusOf(_projectId, _baseRuleset);

        // If the base ruleset has started but wasn't approved if a approval hook exists
        // OR it hasn't started but is currently approved
        // OR it hasn't started but it is likely to be approved and takes place before the proposed one,
        // set the struct to be the ruleset it's based on, which carries the latest approved ruleset.
        if (
            (
                block.timestamp >= _baseRuleset.start
                    && _approvalStatus != JBApprovalStatus.Approved
                    && _approvalStatus != JBApprovalStatus.Empty
            )
                || (
                    block.timestamp < _baseRuleset.start
                        && _mustStartAtOrAfter < _baseRuleset.start + _baseRuleset.duration
                        && _approvalStatus != JBApprovalStatus.Approved
                )
                || (
                    block.timestamp < _baseRuleset.start
                        && _mustStartAtOrAfter >= _baseRuleset.start + _baseRuleset.duration
                        && _approvalStatus != JBApprovalStatus.Approved
                        && _approvalStatus != JBApprovalStatus.ApprovalExpected
                        && _approvalStatus != JBApprovalStatus.Empty
                )
        ) {
            _baseRuleset = _getStructFor(_projectId, _baseRuleset.basedOnId);
        }

        // The specified `rulesetId` can't be the same as the base ruleset's ID.
        if (_baseRuleset.id == _rulesetId) {
            revert BLOCK_ALREADY_CONTAINS_RULESET();
        }

        // The time when the duration of the base ruleset's approval hook has finished.
        // If the provided ruleset has no approval hook, return the current timestamp.
        uint256 _timestampAfterApprovalHook = _baseRuleset.hook
            == IJBRulesetApprovalHook(address(0)) ? 0 : _rulesetId + _baseRuleset.hook.duration();

        _initializeRulesetFor(
            _projectId,
            _baseRuleset,
            _rulesetId,
            // Can only start after the approval hook.
            _timestampAfterApprovalHook > _mustStartAtOrAfter
                ? _timestampAfterApprovalHook
                : _mustStartAtOrAfter,
            _weight
        );
    }

    /// @notice Initializes a ruleset with the specified properties.
    /// @param _projectId The ID of the project to initialize the ruleset for.
    /// @param _baseRuleset The ruleset struct to base the newly initialized one on.
    /// @param _rulesetId The `rulesetId` for the ruleset being initialized.
    /// @param _mustStartAtOrAfter The earliest time the ruleset can start. The ruleset cannot start before this timestamp.
    /// @param _weight The weight to give the newly initialized ruleset.
    function _initializeRulesetFor(
        uint256 _projectId,
        JBRuleset memory _baseRuleset,
        uint256 _rulesetId,
        uint256 _mustStartAtOrAfter,
        uint256 _weight
    ) private {
        // If there is no base, initialize a first ruleset.
        if (_baseRuleset.cycleNumber == 0) {
            // The first cycle number is 1.
            uint256 _rulesetCycleNumber = 1;

            // Set fresh intrinsic properties.
            _packAndStoreIntrinsicPropertiesOf(
                _rulesetId,
                _projectId,
                _rulesetCycleNumber,
                _weight,
                _baseRuleset.id,
                _mustStartAtOrAfter
            );
        } else {
            // Derive the correct next start time from the base.
            uint256 _start = _deriveStartFrom(_baseRuleset, _mustStartAtOrAfter);

            // A weight of 1 is treated as a weight of 0.
            // This is to allow a weight of 0 (default) to represent inheriting the decayed weight of the previous ruleset.
            _weight =
                _weight > 0 ? (_weight == 1 ? 0 : _weight) : _deriveWeightFrom(_baseRuleset, _start);

            // Derive the correct ruleset cycle number.
            uint256 _rulesetCycleNumber = _deriveCycleNumberFrom(_baseRuleset, _start);

            // Update the intrinsic properties.
            _packAndStoreIntrinsicPropertiesOf(
                _rulesetId, _projectId, _rulesetCycleNumber, _weight, _baseRuleset.id, _start
            );
        }

        // Set the project's latest ruleset configuration.
        latestRulesetIdOf[_projectId] = _rulesetId;

        emit RulesetInitialized(_rulesetId, _projectId, _baseRuleset.id);
    }

    /// @notice Efficiently stores the provided intrinsic properties of a ruleset.
    /// @param _rulesetId The `rulesetId` of the ruleset to pack and store for.
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @param _rulesetCycleNumber The cycle number of the ruleset.
    /// @param _weight The weight of the ruleset.
    /// @param _basedOnId The `rulesetId` of the ruleset this ruleset was based on.
    /// @param _start The start time of this ruleset.
    function _packAndStoreIntrinsicPropertiesOf(
        uint256 _rulesetId,
        uint256 _projectId,
        uint256 _rulesetCycleNumber,
        uint256 _weight,
        uint256 _basedOnId,
        uint256 _start
    ) private {
        // `weight` in bits 0-87.
        uint256 packed = _weight;

        // `basedOnId` in bits 88-143.
        packed |= _basedOnId << 88;

        // `start` in bits 144-199.
        packed |= _start << 144;

        // cycle number in bits 200-255.
        packed |= _rulesetCycleNumber << 200;

        // Store the packed value.
        _packedIntrinsicPropertiesOf[_projectId][_rulesetId] = packed;
    }

    /// @notice The ruleset up next for a project, if one exists, whether or not that ruleset has been approved.
    /// @dev A value of 0 is returned if no ruleset was found.
    /// @dev Assumes the project has a `latestRulesetIdOf` value.
    /// @param _projectId The ID of the project to check for an upcoming approvable ruleset.
    /// @return rulesetId The `rulesetId` of the upcoming approvable ruleset if one exists, or 0 if one doesn't exist.
    function _upcomingApprovableRulesetIdOf(uint256 _projectId)
        private
        view
        returns (uint256 rulesetId)
    {
        // Get a reference to the ID of the project's latest ruleset.
        rulesetId = latestRulesetIdOf[_projectId];

        // Get the struct for the latest ruleset.
        JBRuleset memory _ruleset = _getStructFor(_projectId, rulesetId);

        // There is no upcoming ruleset if the latest ruleset has already started.
        if (block.timestamp >= _ruleset.start) return 0;

        // If this is the first ruleset, it is queued.
        if (_ruleset.cycleNumber == 1) return rulesetId;

        // Get a reference to the ID of the ruleset the latest ruleset was based on.
        uint256 _basedOnId = _ruleset.basedOnId;

        // Get the necessary properties for the base ruleset.
        JBRuleset memory _baseRuleset;

        // Find the base ruleset that is not still queued.
        while (true) {
            _baseRuleset = _getStructFor(_projectId, _basedOnId);

            // If the base ruleset starts in the future,
            if (block.timestamp < _baseRuleset.start) {
                // Set the `rulesetId` to the one found.
                rulesetId = _baseRuleset.id;
                // Check the ruleset it was based on in the next iteration.
                _basedOnId = _baseRuleset.basedOnId;
            } else {
                // Break out of the loop when a base ruleset which has already started is found.
                break;
            }
        }

        // Get the ruleset struct for the ID found.
        _ruleset = _getStructFor(_projectId, rulesetId);

        // If the latest ruleset doesn't start until after another base ruleset return 0.
        if (_baseRuleset.duration != 0 && block.timestamp < _ruleset.start - _baseRuleset.duration)
        {
            return 0;
        }
    }

    /// @notice The ID of the ruleset which has started and hasn't expired yet, whether or not it has been approved, for a given project. If approved, this is the active ruleset.
    /// @dev A value of 0 is returned if no ruleset was found.
    /// @dev Assumes the project has a latest ruleset.
    /// @param _projectId The ID of the project to check for a currently approvable ruleset.
    /// @return The ID of a currently approvable ruleset if one exists, or 0 if one doesn't exist.
    function _currentlyApprovableRulesetIdOf(uint256 _projectId) private view returns (uint256) {
        // Get a reference to the project's latest ruleset.
        uint256 _rulesetId = latestRulesetIdOf[_projectId];

        // Get the struct for the latest ruleset.
        JBRuleset memory _ruleset = _getStructFor(_projectId, _rulesetId);

        // Loop through all most recently queued rulesets until an approvable one is found, or we've proven one can't exist.
        do {
            // If the latest ruleset is expired, return an empty ruleset.
            // A ruleset with a duration of 0 cannot expire.
            if (_ruleset.duration != 0 && block.timestamp >= _ruleset.start + _ruleset.duration) {
                return 0;
            }

            // Return the ruleset's `rulesetId` if it has started.
            if (block.timestamp >= _ruleset.start) {
                return _ruleset.id;
            }

            _ruleset = _getStructFor(_projectId, _ruleset.basedOnId);
        } while (_ruleset.cycleNumber != 0);

        return 0;
    }

    /// @notice A simulated view of the ruleset that would be created if the provided one cycled over (if the project doesn't queue a new ruleset).
    /// @dev Returns an empty ruleset if a ruleset can't be simulated based on the provided one.
    /// @dev Assumes a simulated ruleset will never be based on a ruleset with a duration of 0.
    /// @param _baseRuleset The ruleset that the simulated ruleset should be based on.
    /// @param _allowMidRuleset A flag indicating if the simulated ruleset is allowed to already be mid ruleset.
    /// @return A simulated ruleset struct: the next ruleset by default. This will be overwritten if a new ruleset is queued for the project.
    function _simulateCycledRulesetBasedOn(JBRuleset memory _baseRuleset, bool _allowMidRuleset)
        private
        view
        returns (JBRuleset memory)
    {
        // Get the distance from the current time to the start of the next possible ruleset.
        // If the simulated ruleset must not yet have started, the start time of the simulated ruleset must be in the future.
        uint256 _mustStartAtOrAfter =
            !_allowMidRuleset ? block.timestamp + 1 : block.timestamp - _baseRuleset.duration + 1;

        // Calculate what the start time should be.
        uint256 _start = _deriveStartFrom(_baseRuleset, _mustStartAtOrAfter);

        // Calculate what the cycle number should be.
        uint256 _rulesetCycleNumber = _deriveCycleNumberFrom(_baseRuleset, _start);

        return JBRuleset(
            _rulesetCycleNumber,
            _baseRuleset.id,
            _baseRuleset.basedOnId,
            _start,
            _baseRuleset.duration,
            _deriveWeightFrom(_baseRuleset, _start),
            _baseRuleset.decayRate,
            _baseRuleset.hook,
            _baseRuleset.metadata
        );
    }

    /// @notice The date that is the nearest multiple of the base ruleset's duration from the start of the next cycle.
    /// @param _baseRuleset The ruleset to base the calculation on (the previous ruleset).
    /// @param _mustStartAtOrAfter The earliest time the next ruleset can start. The ruleset cannot start before this timestamp.
    /// @return start The next start time.
    function _deriveStartFrom(JBRuleset memory _baseRuleset, uint256 _mustStartAtOrAfter)
        private
        pure
        returns (uint256 start)
    {
        // A subsequent ruleset to one with a duration of 0 should start as soon as possible.
        if (_baseRuleset.duration == 0) return _mustStartAtOrAfter;

        // The time when the ruleset immediately after the specified ruleset starts.
        uint256 _nextImmediateStart = _baseRuleset.start + _baseRuleset.duration;

        // If the next immediate start is now or in the future, return it.
        if (_nextImmediateStart >= _mustStartAtOrAfter) {
            return _nextImmediateStart;
        }

        // The amount of seconds since the `_mustStartAtOrAfter` time which results in a start time that might satisfy the specified limits.
        uint256 _timeFromImmediateStartMultiple =
            (_mustStartAtOrAfter - _nextImmediateStart) % _baseRuleset.duration;

        // A reference to the first possible start timestamp.
        start = _mustStartAtOrAfter - _timeFromImmediateStartMultiple;

        // Add increments of duration as necessary to satisfy the threshold.
        while (_mustStartAtOrAfter > start) {
            start = start + _baseRuleset.duration;
        }
    }

    /// @notice The accumulated weight change since the specified ruleset.
    /// @param _baseRuleset The ruleset to base the calculation on (the previous ruleset).
    /// @param _start The start time of the ruleset to derive a weight for.
    /// @return weight The derived weight, as a fixed point number with 18 decimals.
    function _deriveWeightFrom(JBRuleset memory _baseRuleset, uint256 _start)
        private
        view
        returns (uint256 weight)
    {
        // A subsequent ruleset to one with a duration of 0 should have the next possible weight.
        if (_baseRuleset.duration == 0) {
            return PRBMath.mulDiv(
                _baseRuleset.weight,
                JBConstants.MAX_DECAY_RATE - _baseRuleset.decayRate,
                JBConstants.MAX_DECAY_RATE
            );
        }

        // The weight should be based off the base ruleset's weight.
        weight = _baseRuleset.weight;

        // If the decay is 0, the weight doesn't change.
        if (_baseRuleset.decayRate == 0) return weight;

        // The difference between the start of the base ruleset and the proposed start.
        uint256 _startDistance = _start - _baseRuleset.start;

        // Apply the base ruleset's decay rate for each ruleset that has passed.
        uint256 _decayMultiple;
        unchecked {
            _decayMultiple = _startDistance / _baseRuleset.duration; // Non-null duration is excluded above
        }

        // Check the cache if needed.
        if (_decayMultiple > _DECAY_MULTIPLE_CACHE_LOOKUP_THRESHOLD) {
            // Get a cached weight for the rulesetId.
            JBRulesetWeightCache memory _cache = _weightCacheOf[_baseRuleset.id];

            // If a cached value is available, use it.
            if (_cache.decayMultiple > 0) {
                // Set the starting weight to be the cached value.
                weight = _cache.weight;

                // Set the decay multiple to be the difference between the cached value and the total decay multiple that should be applied.
                _decayMultiple -= _cache.decayMultiple;
            }
        }

        for (uint256 _i; _i < _decayMultiple;) {
            // The number of times to apply the decay rate.
            // Base the new weight on the specified ruleset's weight.
            weight = PRBMath.mulDiv(
                weight,
                JBConstants.MAX_DECAY_RATE - _baseRuleset.decayRate,
                JBConstants.MAX_DECAY_RATE
            );

            // The calculation doesn't need to continue if the weight is 0.
            if (weight == 0) break;

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice The cycle number of the next ruleset given the specified ruleset.
    /// @dev Each time a ruleset starts, whether it was queued or cycled over, the cycle number is incremented by 1.
    /// @param _baseRuleset The previously queued ruleset, to base the calculation on.
    /// @param _start The start time of the ruleset to derive a cycle number for.
    /// @return The ruleset's cycle number.
    function _deriveCycleNumberFrom(JBRuleset memory _baseRuleset, uint256 _start)
        private
        pure
        returns (uint256)
    {
        // A subsequent ruleset to one with a duration of 0 should be the next number.
        if (_baseRuleset.duration == 0) {
            return _baseRuleset.cycleNumber + 1;
        }

        // The difference between the start of the base ruleset and the proposed start.
        uint256 _startDistance = _start - _baseRuleset.start;

        // Find the number of base rulesets that fit in the start distance.
        return _baseRuleset.cycleNumber + (_startDistance / _baseRuleset.duration);
    }

    /// @notice The approval status of a given project and ruleset struct according to the relevant approval hook.
    /// @param _projectId The ID of the project that the ruleset belongs to.
    /// @param _ruleset The ruleset to get an approval flag for.
    /// @return The approval status of the project's ruleset.
    function _approvalStatusOf(uint256 _projectId, JBRuleset memory _ruleset)
        private
        view
        returns (JBApprovalStatus)
    {
        return _approvalStatusOf(_projectId, _ruleset.id, _ruleset.start, _ruleset.basedOnId);
    }

    /// @notice The approval status of a given ruleset (ID) for a given project (ID).
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @param _rulesetId The ID of the ruleset to get the approval status of.
    /// @param _start The start time of the ruleset to get the approval status of.
    /// @param _approvalHookRulesetId The ID of the ruleset with the approval hook that should be checked against.
    /// @return The approval status of the project.
    function _approvalStatusOf(
        uint256 _projectId,
        uint256 _rulesetId,
        uint256 _start,
        uint256 _approvalHookRulesetId
    ) private view returns (JBApprovalStatus) {
        // If there is no ruleset ID to check the approval hook of, the approval hook is empty.
        if (_approvalHookRulesetId == 0) return JBApprovalStatus.Empty;

        // Get the struct of the ruleset with the approval hook.
        JBRuleset memory _approvalHookRuleset = _getStructFor(_projectId, _approvalHookRulesetId);

        // If there is no approval hook, it's considered empty.
        if (_approvalHookRuleset.hook == IJBRulesetApprovalHook(address(0))) {
            return JBApprovalStatus.Empty;
        }

        // Return the approval hook's approval status.
        return _approvalHookRuleset.hook.approvalStatusOf(_projectId, _rulesetId, _start);
    }

    /// @notice Unpack a ruleset's packed stored values into an easy-to-work-with ruleset struct.
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @param _rulesetId The ID of the ruleset to get the full struct for.
    /// @return ruleset A ruleset struct.
    function _getStructFor(uint256 _projectId, uint256 _rulesetId)
        private
        view
        returns (JBRuleset memory ruleset)
    {
        // Return an empty ruleset if the specified `rulesetId` is 0.
        if (_rulesetId == 0) return ruleset;

        ruleset.id = _rulesetId;

        uint256 _packedIntrinsicProperties = _packedIntrinsicPropertiesOf[_projectId][_rulesetId];

        // `weight` in bits 0-87 bits.
        ruleset.weight = uint256(uint88(_packedIntrinsicProperties));
        // `basedOnId` in bits 88-143 bits.
        ruleset.basedOnId = uint256(uint56(_packedIntrinsicProperties >> 88));
        // `start` in bits 144-199 bits.
        ruleset.start = uint256(uint56(_packedIntrinsicProperties >> 144));
        // `cycleNumber` in bits 200-255 bits.
        ruleset.cycleNumber = uint256(uint56(_packedIntrinsicProperties >> 200));

        uint256 _packedUserProperties = _packedUserPropertiesOf[_projectId][_rulesetId];

        // approval hook in bits 0-159 bits.
        ruleset.hook = IJBRulesetApprovalHook(address(uint160(_packedUserProperties)));
        // `duration` in bits 160-191 bits.
        ruleset.duration = uint256(uint32(_packedUserProperties >> 160));
        // decay rate in bits 192-223 bits.
        ruleset.decayRate = uint256(uint32(_packedUserProperties >> 192));

        ruleset.metadata = _metadataOf[_projectId][_rulesetId];
    }
}
