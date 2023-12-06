// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBSplits} from "./interfaces/IJBSplits.sol";
import {IJBSplitHook} from "./interfaces/IJBSplitHook.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBPermissionIds} from "./libraries/JBPermissionIds.sol";
import {JBSplitGroup} from "./structs/JBSplitGroup.sol";
import {JBSplit} from "./structs/JBSplit.sol";
import {JBControlled} from "contracts/abstract/JBControlled.sol";

/// @notice Stores and manages splits for each project.
/// @dev The domain ID is the ruleset ID that a split *should* be considered active within. This is not always the case.
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

    /// @notice The number of splits currently stored in a group given a project ID, domain ID, and group ID.
    /// @custom:param _projectId The ID of the project the domain applies to.
    /// @custom:param _domainId The ID of the domain that the group is specified within.
    /// @custom:param _groupId The ID of the group to count this splits of.
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) private _splitCountOf;

    /// @notice Packed split data given the split's project, domain, and group IDs, as well as the split's index within that group.
    /// @dev `preferAddToBalance` in bit 0, `percent` in bits 1-32, `projectId` in bits 33-88, and `beneficiary` in bits 89-248
    /// @custom:param _projectId The ID of the project that the domain applies to.
    /// @custom:param _domainId The ID of the domain that the group is in.
    /// @custom:param _groupId The ID of the group the split is in.
    /// @custom:param _index The split's index within the group (in the order that the split were set).
    /// @custom:return The split's `preferAddToBalance`, `percent`, `projectId`, and `beneficiary` packed into one `uint256`.
    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) private
        _packedSplitParts1Of;

    /// @notice More packed split data given the split's project, domain, and group IDs, as well as the split's index within that group.
    /// @dev `lockedUntil` in bits 0-47, `hook` address in bits 48-207.
    /// @dev This packed data is often 0.
    /// @custom:param _projectId The ID of the project that the domain applies to.
    /// @custom:param _domainId The ID of the domain that the group is in.
    /// @custom:param _groupId The ID of the group the split is in.
    /// @custom:param _index The split's index within the group (in the order that the split were set).
    /// @custom:return The split's `lockedUntil` and `hook` packed into one `uint256`.
    mapping(uint256 => mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256)))) private
        _packedSplitParts2Of;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Get the split structs for the specified project ID, within the specified domain, for the specified group.
    /// @param _projectId The ID of the project to get splits for.
    /// @param _domainId An identifier within which the returned splits should be considered active.
    /// @param _groupId The identifying group of the splits.
    /// @return An array of all splits for the project.
    function splitsOf(uint256 _projectId, uint256 _domainId, uint256 _groupId)
        external
        view
        override
        returns (JBSplit[] memory)
    {
        return _getStructsFor(_projectId, _domainId, _groupId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _directory A contract storing directories of terminals and controllers for each project.
    constructor(IJBDirectory _directory) JBControlled(_directory) {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets a project's split groups.
    /// @dev Only a project's controller can set its splits.
    /// @dev The new split groups must include any currently set splits that are locked.
    /// @param _projectId The ID of the project to set the split groups of.
    /// @param _domainId The ID of the domain the split groups should be active in.
    /// @param _splitGroups An array of split groups to set.
    function setSplitGroupsOf(
        uint256 _projectId,
        uint256 _domainId,
        JBSplitGroup[] calldata _splitGroups
    ) external override onlyController(_projectId) {
        // Keep a reference to the number of split groups.
        uint256 _numberOfSplitGroups = _splitGroups.length;

        // Set each grouped splits.
        for (uint256 _i; _i < _numberOfSplitGroups;) {
            // Get a reference to the grouped split being iterated on.
            JBSplitGroup memory _splitGroup = _splitGroups[_i];

            // Set the splits for the group.
            _setSplitsOf(_projectId, _domainId, _splitGroup.groupId, _splitGroup.splits);

            unchecked {
                ++_i;
            }
        }
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice Sets the splits for a group given a project, domain, and group ID.
    /// @dev The new splits must include any currently set splits that are locked.
    /// @dev The sum of the split `percent`s within one group must be less than 100%.
    /// @param _projectId The ID of the project splits are being set for.
    /// @param _domainId The ID of the domain the splits should be considered active within.
    /// @param _groupId The ID of the group to set the splits within.
    /// @param _splits An array of splits to set.
    function _setSplitsOf(
        uint256 _projectId,
        uint256 _domainId,
        uint256 _groupId,
        JBSplit[] memory _splits
    ) internal {
        // Get a reference to the current split structs within the project, domain, and group.
        JBSplit[] memory _currentSplits = _getStructsFor(_projectId, _domainId, _groupId);

        // Keep a reference to the current number of splits within the group.
        uint256 _numberOfCurrentSplits = _currentSplits.length;

        // Check to see if all locked splits are included in the array of splits which is being set.
        for (uint256 _i; _i < _numberOfCurrentSplits;) {
            // If not locked, continue.
            if (
                block.timestamp < _currentSplits[_i].lockedUntil
                    && !_includesLockedSplits(_splits, _currentSplits[_i])
            ) revert PREVIOUS_LOCKED_SPLITS_NOT_INCLUDED();

            unchecked {
                ++_i;
            }
        }

        // Add up all the `percent`s to make sure their total is under 100%.
        uint256 _percentTotal;

        // Keep a reference to the number of splits to set.
        uint256 _numberOfSplits = _splits.length;

        for (uint256 _i; _i < _numberOfSplits;) {
            // The percent should be greater than 0.
            if (_splits[_i].percent == 0) revert INVALID_SPLIT_PERCENT();

            // `projectId` should fit within a uint56
            if (_splits[_i].projectId > type(uint56).max) revert INVALID_PROJECT_ID();

            // Add to the `percent` total.
            _percentTotal = _percentTotal + _splits[_i].percent;

            // Ensure the total does not exceed 100%.
            if (_percentTotal > JBConstants.SPLITS_TOTAL_PERCENT) revert INVALID_TOTAL_PERCENT();

            uint256 _packedSplitParts1;

            // Pack `preferAddToBalance` in bit 0.
            if (_splits[_i].preferAddToBalance) _packedSplitParts1 = 1;
            // Pack `percent` in bits 1-32.
            _packedSplitParts1 |= _splits[_i].percent << 1;
            // Pack `projectId` in bits 33-88.
            _packedSplitParts1 |= _splits[_i].projectId << 33;
            // Pack `beneficiary` in bits 89-248.
            _packedSplitParts1 |= uint256(uint160(address(_splits[_i].beneficiary))) << 89;

            // Store the first split part.
            _packedSplitParts1Of[_projectId][_domainId][_groupId][_i] = _packedSplitParts1;

            // If there's data to store in the second packed split part, pack and store.
            if (_splits[_i].lockedUntil > 0 || _splits[_i].hook != IJBSplitHook(address(0))) {
                // `lockedUntil` should fit within a uint48
                if (_splits[_i].lockedUntil > type(uint48).max) revert INVALID_LOCKED_UNTIL();

                // Pack `lockedUntil` in bits 0-47.
                uint256 _packedSplitParts2 = uint48(_splits[_i].lockedUntil);
                // Pack `hook` in bits 48-207.
                _packedSplitParts2 |= uint256(uint160(address(_splits[_i].hook))) << 48;

                // Store the second split part.
                _packedSplitParts2Of[_projectId][_domainId][_groupId][_i] = _packedSplitParts2;
            } else if (_packedSplitParts2Of[_projectId][_domainId][_groupId][_i] > 0) {
                // If there's a value stored in the indexed position, delete it.
                delete _packedSplitParts2Of[_projectId][_domainId][_groupId][_i];
            }

            emit SetSplit(_projectId, _domainId, _groupId, _splits[_i], msg.sender);

            unchecked {
                ++_i;
            }
        }

        // Store the number of splits for the project, domain, and group.
        _splitCountOf[_projectId][_domainId][_groupId] = _numberOfSplits;
    }

    /// @notice Determine if the provided splits array includes the locked split.
    /// @param _splits The array of splits to check within.
    /// @param _lockedSplit The locked split.
    /// @return A flag indicating if the `_lockedSplit` is contained in the `_splits`.
    function _includesLockedSplits(JBSplit[] memory _splits, JBSplit memory _lockedSplit)
        private
        pure
        returns (bool)
    {
        // Keep a reference to the number of splits.
        uint256 _numberOfSplits = _splits.length;

        for (uint256 _i; _i < _numberOfSplits;) {
            // Check for sameness.
            if (
                _splits[_i].percent == _lockedSplit.percent
                    && _splits[_i].beneficiary == _lockedSplit.beneficiary
                    && _splits[_i].hook == _lockedSplit.hook
                    && _splits[_i].projectId == _lockedSplit.projectId
                    && _splits[_i].preferAddToBalance == _lockedSplit.preferAddToBalance
                // Allow the lock to be extended.
                && _splits[_i].lockedUntil >= _lockedSplit.lockedUntil
            ) return true;

            unchecked {
                ++_i;
            }
        }

        return false;
    }

    /// @notice Unpack an array of `JBSplit` structs for all of the splits in a group, given project, domain, and group IDs.
    /// @param _projectId The ID of the project the splits belong to.
    /// @param _domainId The ID of the domain the group of splits should be considered active within.
    /// @param _groupId The ID of the group to get the splits structs of.
    /// @return splits The split structs, as an array of `JBSplit`s.
    function _getStructsFor(uint256 _projectId, uint256 _domainId, uint256 _groupId)
        private
        view
        returns (JBSplit[] memory)
    {
        // Get a reference to the number of splits that need to be added to the returned array.
        uint256 _splitCount = _splitCountOf[_projectId][_domainId][_groupId];

        // Initialize an array to be returned that has the appropriate length.
        JBSplit[] memory _splits = new JBSplit[](_splitCount);

        // Loop through each split and unpack the values into structs.
        for (uint256 _i; _i < _splitCount;) {
            // Get a reference to the first part of the split's packed data.
            uint256 _packedSplitPart1 = _packedSplitParts1Of[_projectId][_domainId][_groupId][_i];

            // Populate the split struct.
            JBSplit memory _split;

            // `preferAddToBalance` in bit 0.
            _split.preferAddToBalance = _packedSplitPart1 & 1 == 1;
            // `percent` in bits 1-32.
            _split.percent = uint256(uint32(_packedSplitPart1 >> 1));
            // `projectId` in bits 33-88.
            _split.projectId = uint256(uint56(_packedSplitPart1 >> 33));
            // `beneficiary` in bits 89-248.
            _split.beneficiary = payable(address(uint160(_packedSplitPart1 >> 89)));

            // Get a reference to the second part of the split's packed data.
            uint256 _packedSplitPart2 = _packedSplitParts2Of[_projectId][_domainId][_groupId][_i];

            // If there's anything in it, unpack.
            if (_packedSplitPart2 > 0) {
                // `lockedUntil` in bits 0-47.
                _split.lockedUntil = uint256(uint48(_packedSplitPart2));
                // `hook` in bits 48-207.
                _split.hook = IJBSplitHook(address(uint160(_packedSplitPart2 >> 48)));
            }

            // Add the split to the value being returned.
            _splits[_i] = _split;

            unchecked {
                ++_i;
            }
        }

        return _splits;
    }
}
