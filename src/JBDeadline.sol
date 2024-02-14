// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBApprovalStatus} from "./enums/JBApprovalStatus.sol";
import {IJBRulesetApprovalHook} from "./interfaces/IJBRulesetApprovalHook.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";

/// @notice Ruleset approval hook which rejects rulesets if they are not queued at least `duration` seconds before the
/// current ruleset ends. In other words, rulesets must be queued before the deadline to take effect.
contract JBDeadline is ERC165, IJBRulesetApprovalHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    /// @notice Throw if the duration used to initialize this contract is too long.
    error DURATION_TOO_LONG();

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The minimum difference between the time a ruleset is queued and the time it starts, as a number of
    /// seconds. If the difference is greater than this number, the ruleset is `Approved`.
    uint256 public immutable override DURATION;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The approval status of a particular ruleset.
    /// @param projectId The ID of the project to which the ruleset being checked belongs.
    /// @param rulesetId The `rulesetId` of the ruleset to check the status of. The `rulesetId` is the timestamp for
    /// when ruleset was queued.
    /// @param start The start timestamp of the ruleset to check the status of.
    /// @return The status of the approval hook.
    function approvalStatusOf(
        uint256 projectId,
        uint256 rulesetId,
        uint256 start
    )
        public
        view
        override
        returns (JBApprovalStatus)
    {
        projectId; // Prevents unused var compiler and natspec complaints.

        // If the provided rulesetId timestamp is after the start timestamp, the approval hook is Failed.
        if (rulesetId > start) return JBApprovalStatus.Failed;

        unchecked {
            // If there was sufficient time between queuing and the start of the ruleset, it is approved. Otherwise, it
            // is failed.
            // If the approval hook hasn't yet started, its approval status is ApprovalExpected.
            return (start - rulesetId < DURATION)
                ? JBApprovalStatus.Failed
                : (block.timestamp < start - DURATION) ? JBApprovalStatus.ApprovalExpected : JBApprovalStatus.Approved;
        }
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherance to.
    /// @return A flag indicating if this contract adheres to the specified interface.
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IJBRulesetApprovalHook).interfaceId || super.supportsInterface(interfaceId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param duration The minimum number of seconds between the time a ruleset is queued and that ruleset's `start`
    /// for it to be `Approved`.
    constructor(uint256 duration) {
        // Ensure we don't underflow in `approvalStatusOf(...)`.
        if (duration > block.timestamp) revert DURATION_TOO_LONG();

        DURATION = duration;
    }
}
