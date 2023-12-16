// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Context} from "lib/openzeppelin-contracts/contracts/utils/Context.sol";
import {IJBPermissioned} from "./../interfaces/IJBPermissioned.sol";
import {IJBPermissions} from "./../interfaces/IJBPermissions.sol";

/// @notice Modifiers to allow access to transactions based on which permissions the message's sender has.
abstract contract JBPermissioned is Context, IJBPermissioned {
    //*********************************************************************//
    // --------------------------- custom errors -------------------------- //
    //*********************************************************************//
    error UNAUTHORIZED();

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice A contract storing permissions.
    IJBPermissions public immutable override PERMISSIONS;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param permissions A contract storing permissions.
    constructor(IJBPermissions permissions) {
        PERMISSIONS = permissions;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Require the message sender to be the account or have the relevant permission.
    /// @param account The account to allow.
    /// @param projectId The project ID to check the permission under.
    /// @param permissionId The required permission ID. The operator must have this permission within the specified
    /// project ID.
    function _requirePermissionBy(address account, uint256 projectId, uint256 permissionId) internal view {
        address sender = _msgSender();
        if (
            sender != account && !PERMISSIONS.hasPermission(sender, account, projectId, permissionId)
                && !PERMISSIONS.hasPermission(sender, account, 0, permissionId)
        ) revert UNAUTHORIZED();
    }

    /// @notice If the 'alsoGrantAccessIf' condition is truthy, proceed. Otherwise, require the message sender to be the
    /// account or
    /// have the relevant permission.
    /// @param account The account to allow.
    /// @param projectId The project ID to check the permission under.
    /// @param permissionId The required permission ID. The operator must have this permission within the specified
    /// project ID.
    /// @param alsoGrantAccessIf An override condition which will allow access regardless of permissions.
    function _requirePermissionAllowingOverride(
        address account,
        uint256 projectId,
        uint256 permissionId,
        bool alsoGrantAccessIf
    )
        internal
        view
    {
        if (alsoGrantAccessIf) return;
        _requirePermissionBy(account, projectId, permissionId);
    }
}
