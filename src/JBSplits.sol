// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBControlled} from "./abstract/JBControlled.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBSplitHook} from "./interfaces/IJBSplitHook.sol";
import {IJBSplits} from "./interfaces/IJBSplits.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBSplit} from "./structs/JBSplit.sol";
import {JBSplitGroup} from "./structs/JBSplitGroup.sol";

/// @notice Stores and manages splits for each project.
contract JBSplits is JBControlled, IJBSplits {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error JBSplits_TotalPercentExceeds100();
    error JBSplits_PreviousLockedSplitsNotIncluded();
    error JBSplits_ZeroSplitPercent();

    //*********************************************************************//
    // ------------------------- public constants ------------------------ //
    //*********************************************************************//

    /// @notice The ID of the ruleset that will be checked if nothing was found in the provided rulesetId.
    uint256 public constant override FALLBACK_RULESET_ID = 0;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice Packed split data given the split's project, ruleset, and group IDs, as well as the split's index within
    /// that group.
    /// @dev `preferAddToBalance` in bit 0, `percent` in bits 1-32, `projectId` in bits 33-88, and `beneficiary` in bits
    /// 89-248
    /// @custom:param projectId The ID of the project that the split applies to.
    /// @custom:param rulesetId The ID of the ruleset that the group is in.
    /// @custom:param groupId The ID of the group the split is in.
    /// @custom:param index The split's index within the group (in the order that the split were set).
    /// @custom:return The split's `preferAddToBalance`, `percent`, `projectId`, and `beneficiary` packed into one
    /// `uint256`.
    mapping(
        uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => mapping(uint256 index => uint256)))
    ) internal _packedSplitParts1Of;

    /// @notice More packed split data given the split's project, ruleset, and group IDs, as well as the split's index
    /// within that group.
    /// @dev `lockedUntil` in bits 0-47, `hook` address in bits 48-207.
    /// @dev This packed data is often 0.
    /// @custom:param projectId The ID of the project that the ruleset applies to.
    /// @custom:param rulesetId The ID of the ruleset that the group is in.
    /// @custom:param groupId The ID of the group the split is in.
    /// @custom:param index The split's index within the group (in the order that the split were set).
    /// @custom:return The split's `lockedUntil` and `hook` packed into one `uint256`.
    mapping(
        uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => mapping(uint256 index => uint256)))
    ) internal _packedSplitParts2Of;

    /// @notice The number of splits currently stored in a group given a project ID, ruleset ID, and group ID.
    /// @custom:param projectId The ID of the project the split applies to.
    /// @custom:param rulesetId The ID of the ruleset that the group is specified within.
    /// @custom:param groupId The ID of the group to count this splits of.
    mapping(uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => uint256))) internal
        _splitCountOf;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    constructor(IJBDirectory directory) JBControlled(directory) {}

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Get the split structs for the specified project ID, within the specified ruleset, for the specified
    /// group. The splits stored at ruleset 0 are used by default during a ruleset if the splits for the specific
    /// ruleset aren't set.
    /// @dev If splits aren't found at the given `rulesetId`, they'll be sought in the FALLBACK_RULESET_ID of 0.
    /// @param projectId The ID of the project to get splits for.
    /// @param rulesetId An identifier within which the returned splits should be considered active.
    /// @param groupId The identifying group of the splits.
    /// @return splits An array of all splits for the project.
    function splitsOf(
        uint256 projectId,
        uint256 rulesetId,
        uint256 groupId
    )
        external
        view
        override
        returns (JBSplit[] memory splits)
    {
        splits = _getStructsFor(projectId, rulesetId, groupId);

        // Use the default splits if there aren't any for the ruleset.
        if (splits.length == 0) {
            splits = _getStructsFor({projectId: projectId, rulesetId: FALLBACK_RULESET_ID, groupId: groupId});
        }
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Unpack an array of `JBSplit` structs for all of the splits in a group, given project, ruleset, and group
    /// IDs.
    /// @param projectId The ID of the project the splits belong to.
    /// @param rulesetId The ID of the ruleset the group of splits should be considered active within.
    /// @param groupId The ID of the group to get the splits structs of.
    /// @return splits The split structs, as an array of `JBSplit`s.
    function _getStructsFor(
        uint256 projectId,
        uint256 rulesetId,
        uint256 groupId
    )
        internal
        view
        returns (JBSplit[] memory)
    {
        // Get a reference to the number of splits that need to be added to the returned array.
        uint256 splitCount = _splitCountOf[projectId][rulesetId][groupId];

        // Initialize an array to be returned that has the appropriate length.
        JBSplit[] memory splits = new JBSplit[](splitCount);

        // Loop through each split and unpack the values into structs.
        for (uint256 i; i < splitCount; i++) {
            // Get a reference to the first part of the split's packed data.
            uint256 packedSplitPart1 = _packedSplitParts1Of[projectId][rulesetId][groupId][i];

            // Populate the split struct.
            JBSplit memory split;

            // `percent` in bits 0-31.
            split.percent = uint32(packedSplitPart1);
            // `projectId` in bits 32-95.
            split.projectId = uint64(packedSplitPart1 >> 32);
            // `beneficiary` in bits 96-255.
            split.beneficiary = payable(address(uint160(packedSplitPart1 >> 96)));

            // Get a reference to the second part of the split's packed data.
            uint256 packedSplitPart2 = _packedSplitParts2Of[projectId][rulesetId][groupId][i];

            // If there's anything in it, unpack.
            if (packedSplitPart2 > 0) {
                // `preferAddToBalance` in bit 0.
                split.preferAddToBalance = packedSplitPart1 & 1 == 1;
                // `lockedUntil` in bits 1-48.
                split.lockedUntil = uint48(packedSplitPart2 >> 1);
                // `hook` in bits 49-208.
                split.hook = IJBSplitHook(address(uint160(packedSplitPart2 >> 49)));
            }

            // Add the split to the value being returned.
            splits[i] = split;
        }

        return splits;
    }

    /// @notice Determine if the provided splits array includes the locked split.
    /// @param splits The array of splits to check within.
    /// @param lockedSplit The locked split.
    /// @return A flag indicating if the `lockedSplit` is contained in the `splits`.
    function _includesLockedSplits(JBSplit[] memory splits, JBSplit memory lockedSplit) internal pure returns (bool) {
        // Keep a reference to the number of splits.
        uint256 numberOfSplits = splits.length;

        for (uint256 i; i < numberOfSplits; i++) {
            // Set the split being iterated on.
            JBSplit memory split = splits[i];

            // Check for sameness.
            if (
                // Allow the lock to be extended.
                split.percent == lockedSplit.percent && split.beneficiary == lockedSplit.beneficiary
                    && split.hook == lockedSplit.hook && split.projectId == lockedSplit.projectId
                    && split.preferAddToBalance == lockedSplit.preferAddToBalance
                    && split.lockedUntil >= lockedSplit.lockedUntil
            ) return true;
        }

        return false;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets a project's split groups.
    /// @dev Only a project's controller can set its splits.
    /// @dev The new split groups must include any currently set splits that are locked.
    /// @param projectId The ID of the project to set the split groups of.
    /// @param rulesetId The ID of the ruleset the split groups should be active in. Send
    /// 0 to set the default split that'll be active if no ruleset has specific splits set. The default's default is the
    /// project's owner.
    /// @param splitGroups An array of split groups to set.
    function setSplitGroupsOf(
        uint256 projectId,
        uint256 rulesetId,
        JBSplitGroup[] calldata splitGroups
    )
        external
        override
        onlyControllerOf(projectId)
    {
        // Set each grouped splits.
        for (uint256 i; i < splitGroups.length; i++) {
            // Get a reference to the grouped split being iterated on.
            JBSplitGroup memory splitGroup = splitGroups[i];

            // Set the splits for the group.
            _setSplitsOf(projectId, rulesetId, splitGroup.groupId, splitGroup.splits);
        }
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Sets the splits for a group given a project, ruleset, and group ID.
    /// @dev The new splits must include any currently set splits that are locked.
    /// @dev The sum of the split `percent`s within one group must be less than 100%.
    /// @param projectId The ID of the project splits are being set for.
    /// @param rulesetId The ID of the ruleset the splits should be considered active within.
    /// @param groupId The ID of the group to set the splits within.
    /// @param splits An array of splits to set.
    function _setSplitsOf(uint256 projectId, uint256 rulesetId, uint256 groupId, JBSplit[] memory splits) internal {
        // Get a reference to the current split structs within the project, ruleset, and group.
        JBSplit[] memory currentSplits = _getStructsFor(projectId, rulesetId, groupId);

        // Keep a reference to the current number of splits within the group.
        uint256 numberOfCurrentSplits = currentSplits.length;

        // Check to see if all locked splits are included in the array of splits which is being set.
        for (uint256 i; i < numberOfCurrentSplits; i++) {
            // If not locked, continue.
            if (block.timestamp < currentSplits[i].lockedUntil && !_includesLockedSplits(splits, currentSplits[i])) {
                revert JBSplits_PreviousLockedSplitsNotIncluded();
            }
        }

        // Add up all the `percent`s to make sure their total is under 100%.
        uint256 percentTotal;

        // Keep a reference to the number of splits to set.
        uint256 numberOfSplits = splits.length;

        for (uint256 i; i < numberOfSplits; i++) {
            // Set the split being iterated on.
            JBSplit memory split = splits[i];

            // The percent should be greater than 0.
            if (split.percent == 0) revert JBSplits_ZeroSplitPercent();

            // Add to the `percent` total.
            percentTotal += split.percent;

            // Ensure the total does not exceed 100%.
            if (percentTotal > JBConstants.SPLITS_TOTAL_PERCENT) revert JBSplits_TotalPercentExceeds100();

            uint256 packedSplitParts1;

            // Pack `percent` in bits 0-31.
            packedSplitParts1 = split.percent;
            // Pack `projectId` in bits 32-95.
            packedSplitParts1 |= split.projectId << 32;
            // Pack `beneficiary` in bits 96-255.
            packedSplitParts1 |= uint256(uint160(address(split.beneficiary))) << 96;

            // Store the first split part.
            _packedSplitParts1Of[projectId][rulesetId][groupId][i] = packedSplitParts1;

            // If there's data to store in the second packed split part, pack and store.
            if (split.preferAddToBalance || split.lockedUntil > 0 || split.hook != IJBSplitHook(address(0))) {
                // Pack `preferAddToBalance` in bit 0.
                uint256 packedSplitParts2 = split.preferAddToBalance ? 1 : 0;
                // Pack `lockedUntil` in bits 1-48.
                packedSplitParts2 |= split.lockedUntil << 1;
                // Pack `hook` in bits 49-208.
                packedSplitParts2 |= uint256(uint160(address(split.hook))) << 48;

                // Store the second split part.
                _packedSplitParts2Of[projectId][rulesetId][groupId][i] = packedSplitParts2;
            } else if (_packedSplitParts2Of[projectId][rulesetId][groupId][i] > 0) {
                // If there's a value stored in the indexed position, delete it.
                delete _packedSplitParts2Of[projectId][rulesetId][groupId][i];
            }

            emit SetSplit({
                projectId: projectId,
                rulesetId: rulesetId,
                groupId: groupId,
                split: split,
                caller: msg.sender
            });
        }

        // Store the number of splits for the project, ruleset, and group.
        _splitCountOf[projectId][rulesetId][groupId] = numberOfSplits;
    }
}
