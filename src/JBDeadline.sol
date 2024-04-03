// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBApprovalStatus} from "./enums/JBApprovalStatus.sol";
import {IJBRulesetApprovalHook} from "./interfaces/IJBRulesetApprovalHook.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";

/// @notice `JBDeadline` is a ruleset approval hook which rejects rulesets if they are not queued at least `duration`
/// seconds before the current ruleset ends. In other words, rulesets must be queued before the deadline to take effect.
/// @dev Project rulesets are stored in a queue. Rulesets take effect after the previous ruleset in the queue ends, and
/// only if they are approved by the previous ruleset's approval hook.
contract JBDeadline is IJBRulesetApprovalHook {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error DURATION_TOO_LONG();

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The minimum number of seconds between the time a ruleset is queued and the time it starts. If the
    /// difference is greater than this number, the ruleset is `Approved`.
    uint256 public immutable override DURATION;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The approval status of a given ruleset.
    /// @param projectId The ID of the project the ruleset belongs to.
    /// @param rulesetId The ID of the ruleset to check the status of.
    /// @param start The start timestamp of the ruleset to check the status of.
    /// @return The ruleset's approval status.
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

        // The ruleset ID is the timestamp at which the ruleset was queued.
        // If the provided `rulesetId` timestamp is after the start timestamp, the ruleset has `Failed`.
        if (rulesetId > start) return JBApprovalStatus.Failed;

        unchecked {
            // If there aren't enough seconds between the time the ruleset was queued and the time it starts, it has
            // `Failed`.
            // Otherwise, if there is still time before the deadline, the ruleset's status is `ApprovalExpected`.
            // If we've already passed the deadline, the ruleset is `Approved`.
            return (start - rulesetId < DURATION)
                ? JBApprovalStatus.Failed
                : (block.timestamp < start - DURATION) ? JBApprovalStatus.ApprovalExpected : JBApprovalStatus.Approved;
        }
    }

    /// @notice Indicates whether this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    /// @return A flag indicating if this contract adheres to the specified interface.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IJBRulesetApprovalHook).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param duration The minimum number of seconds between the time a ruleset is queued and the time it starts for it
    /// to be `Approved`.
    constructor(uint256 duration) {
        // Ensure we don't underflow in `approvalStatusOf(...)`.
        if (duration > block.timestamp) revert DURATION_TOO_LONG();

        DURATION = duration;
    }
}
