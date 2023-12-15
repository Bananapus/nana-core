// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBSplits} from "./interfaces/IJBSplits.sol";
import {IJBSplitHook} from "./interfaces/IJBSplitHook.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBPermissionIds} from "./libraries/JBPermissionIds.sol";
import {JBSplitGroup} from "./structs/JBSplitGroup.sol";
import {JBSplit} from "./structs/JBSplit.sol";
import {JBControlled} from "./abstract/JBControlled.sol";

/// @notice Stores and manages splits for each project.
contract JBSplits is JBControlled, IJBSplits {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error INVALID_LOCKED_UNTIL();
    error INVALID_PROJECT_ID();
    error INVALID_SPLIT_PERCENT();
    error INVALID_TOTAL_PERCENT();
    error PREVIOUS_LOCKED_SPLITS_NOT_INCLUDED();

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    /// @notice The number of splits currently stored in a group given a project ID, ruleset ID, and group ID.
    /// @custom:param projectId The ID of the project the split applies to.
    /// @custom:param rulesetId The ID of the ruleset that the group is specified within.
    /// @custom:param groupId The ID of the group to count this splits of.
    mapping(uint256 projectId => mapping(uint256 rulesetId => mapping(uint256 groupId => uint256))) private
        _splitCountOf;

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
    ) private _packedSplitParts1Of;

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
    ) private _packedSplitParts2Of;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Get the split structs for the specified project ID, within the specified ruleset, for the specified
    /// group. The splits stored at ruleset 0 are used by default during a ruleset if the splits for the specific
    /// ruleset aren't set.
    /// @param projectId The ID of the project to get splits for.
    /// @param rulesetId An identifier within which the returned splits should be considered active.
    /// @param groupId The identifying group of the splits.
    /// @return An array of all splits for the project.
    function splitsOf(
        uint256 projectId,
        uint256 rulesetId,
        uint256 groupId
    )
        external
        view
        override
        returns (JBSplit[] memory)
    {
        return _getStructsFor(projectId, rulesetId, groupId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    constructor(IJBDirectory directory) JBControlled(directory) {}

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
        // Keep a reference to the number of split groups.
        uint256 numberOfSplitGroups = splitGroups.length;

        // Set each grouped splits.
        for (uint256 i; i < numberOfSplitGroups; ++i) {
            // Get a reference to the grouped split being iterated on.
            JBSplitGroup memory splitGroup = splitGroups[i];

            // Set the splits for the group.
            _setSplitsOf(projectId, rulesetId, splitGroup.groupId, splitGroup.splits);
        }
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice Sets the splits for a group given a project, ruleset, and group ID.
    /// @dev The new splits must include any currently set splits that are locked.
    /// @dev The sum of the split `percent`s within one group must be less than 100%.
    /// @param projectId The ID of the project splits are being set for.
    /// @param rulesetId The ID of the ruleset the splits should be considered active within.
    /// @param groupId The ID of the group to set the splits within.
    /// @param splits An array of splits to set.
    function _setSplitsOf(uint256 projectId, uint256 rulesetId, uint256 groupId, JBSplit[] memory splits) private {
        // Get a reference to the current split structs within the project, ruleset, and group.
        JBSplit[] memory currentSplits = _getStructsFor(projectId, rulesetId, groupId);

        // Keep a reference to the current number of splits within the group.
        uint256 numberOfCurrentSplits = currentSplits.length;

        // Check to see if all locked splits are included in the array of splits which is being set.
        for (uint256 i; i < numberOfCurrentSplits; ++i) {
            // If not locked, continue.
            if (block.timestamp < currentSplits[i].lockedUntil && !_includesLockedSplits(splits, currentSplits[i])) {
                revert PREVIOUS_LOCKED_SPLITS_NOT_INCLUDED();
            }
        }

        // Add up all the `percent`s to make sure their total is under 100%.
        uint256 percentTotal;

        // Keep a reference to the number of splits to set.
        uint256 numberOfSplits = splits.length;

        for (uint256 i; i < numberOfSplits; ++i) {
            // The percent should be greater than 0.
            if (splits[i].percent == 0) revert INVALID_SPLIT_PERCENT();

            // `projectId` should fit within a uint56
            if (splits[i].projectId > type(uint56).max) revert INVALID_PROJECT_ID();

            // Add to the `percent` total.
            percentTotal = percentTotal + splits[i].percent;

            // Ensure the total does not exceed 100%.
            if (percentTotal > JBConstants.SPLITS_TOTAL_PERCENT) revert INVALID_TOTAL_PERCENT();

            uint256 packedSplitParts1;

            // Pack `preferAddToBalance` in bit 0.
            if (splits[i].preferAddToBalance) packedSplitParts1 = 1;
            // Pack `percent` in bits 1-32.
            packedSplitParts1 |= splits[i].percent << 1;
            // Pack `projectId` in bits 33-88.
            packedSplitParts1 |= splits[i].projectId << 33;
            // Pack `beneficiary` in bits 89-248.
            packedSplitParts1 |= uint256(uint160(address(splits[i].beneficiary))) << 89;

            // Store the first split part.
            _packedSplitParts1Of[projectId][rulesetId][groupId][i] = packedSplitParts1;

            // If there's data to store in the second packed split part, pack and store.
            if (splits[i].lockedUntil > 0 || splits[i].hook != IJBSplitHook(address(0))) {
                // `lockedUntil` should fit within a uint48
                if (splits[i].lockedUntil > type(uint48).max) revert INVALID_LOCKED_UNTIL();

                // Pack `lockedUntil` in bits 0-47.
                uint256 packedSplitParts2 = uint48(splits[i].lockedUntil);
                // Pack `hook` in bits 48-207.
                packedSplitParts2 |= uint256(uint160(address(splits[i].hook))) << 48;

                // Store the second split part.
                _packedSplitParts2Of[projectId][rulesetId][groupId][i] = packedSplitParts2;
            } else if (_packedSplitParts2Of[projectId][rulesetId][groupId][i] > 0) {
                // If there's a value stored in the indexed position, delete it.
                delete _packedSplitParts2Of[projectId][rulesetId][groupId][i];
            }

            emit SetSplit(projectId, rulesetId, groupId, splits[i], msg.sender);
        }

        // Store the number of splits for the project, ruleset, and group.
        _splitCountOf[projectId][rulesetId][groupId] = numberOfSplits;
    }

    /// @notice Determine if the provided splits array includes the locked split.
    /// @param splits The array of splits to check within.
    /// @param lockedSplit The locked split.
    /// @return A flag indicating if the `lockedSplit` is contained in the `splits`.
    function _includesLockedSplits(JBSplit[] memory splits, JBSplit memory lockedSplit) private pure returns (bool) {
        // Keep a reference to the number of splits.
        uint256 numberOfSplits = splits.length;

        for (uint256 i; i < numberOfSplits; ++i) {
            // Check for sameness.
            if (
                splits[i].percent == lockedSplit.percent && splits[i].beneficiary == lockedSplit.beneficiary
                    && splits[i].hook == lockedSplit.hook && splits[i].projectId == lockedSplit.projectId
                    && splits[i].preferAddToBalance == lockedSplit.preferAddToBalance
                // Allow the lock to be extended.
                && splits[i].lockedUntil >= lockedSplit.lockedUntil
            ) return true;
        }

        return false;
    }

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
        private
        view
        returns (JBSplit[] memory)
    {
        // Get a reference to the number of splits that need to be added to the returned array.
        uint256 splitCount = _splitCountOf[projectId][rulesetId][groupId];

        // Initialize an array to be returned that has the appropriate length.
        JBSplit[] memory splits = new JBSplit[](splitCount);

        // Loop through each split and unpack the values into structs.
        for (uint256 i; i < splitCount; ++i) {
            // Get a reference to the first part of the split's packed data.
            uint256 packedSplitPart1 = _packedSplitParts1Of[projectId][rulesetId][groupId][i];

            // Populate the split struct.
            JBSplit memory split;

            // `preferAddToBalance` in bit 0.
            split.preferAddToBalance = packedSplitPart1 & 1 == 1;
            // `percent` in bits 1-32.
            split.percent = uint256(uint32(packedSplitPart1 >> 1));
            // `projectId` in bits 33-88.
            split.projectId = uint256(uint56(packedSplitPart1 >> 33));
            // `beneficiary` in bits 89-248.
            split.beneficiary = payable(address(uint160(packedSplitPart1 >> 89)));

            // Get a reference to the second part of the split's packed data.
            uint256 packedSplitPart2 = _packedSplitParts2Of[projectId][rulesetId][groupId][i];

            // If there's anything in it, unpack.
            if (packedSplitPart2 > 0) {
                // `lockedUntil` in bits 0-47.
                split.lockedUntil = uint256(uint48(packedSplitPart2));
                // `hook` in bits 48-207.
                split.hook = IJBSplitHook(address(uint160(packedSplitPart2 >> 48)));
            }

            // Add the split to the value being returned.
            splits[i] = split;
        }

        return splits;
    }
}
