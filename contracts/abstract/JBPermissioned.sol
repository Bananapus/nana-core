// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IJBPermissioned} from "./../interfaces/IJBPermissioned.sol";
import {IJBPermissions} from "./../interfaces/IJBPermissions.sol";

/// @notice Modifiers to allow access to functions based on which permissions the message's sender has.
abstract contract JBPermissioned is Context, IJBPermissioned {
    //*********************************************************************//
    // --------------------------- custom errors -------------------------- //
    //*********************************************************************//
    error UNAUTHORIZED();

    //*********************************************************************//
    // ---------------------------- modifiers ---------------------------- //
    //*********************************************************************//

    /// @notice Restrict access to the specified account, or an operator they have given permissions to.
    /// @param _account The account to check for.
    /// @param _projectId The project ID to check permissions under.
    /// @param _permissionId The ID of the permission to check for.
    modifier requirePermission(address _account, uint256 _projectId, uint256 _permissionId) {
        _requirePermission(_account, _projectId, _permissionId);
        _;
    }

    /// @notice If the `_override` flag is truthy, proceed. Otherwise, restrict access to the specified account, and operator(s) they have given permissions to.
    /// @param _account The account to check for.
    /// @param _projectId The project ID to check permissions under.
    /// @param _permissionId The ID of the permission to check for.
    /// @param _override An override which will allow access regardless of permissions.
    modifier requirePermissionAllowingOverride(
        address _account,
        uint256 _projectId,
        uint256 _permissionId,
        bool _override
    ) {
        _requirePermissionAllowingOverride(_account, _projectId, _permissionId, _override);
        _;
    }

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice A contract storing permissions.
    IJBPermissions public immutable override permissions;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _permissions A contract storing permissions.
    constructor(IJBPermissions _permissions) {
        permissions = _permissions;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Require the message sender to be the account or have the relevant permission.
    /// @param _account The account to allow.
    /// @param _projectId The project ID to check the permission under.
    /// @param _permissionId The required permission ID. The operator must have this permission within the specified project ID.
    function _requirePermission(address _account, uint256 _projectId, uint256 _permissionId)
        internal
        view
    {
        address _sender = _msgSender();
        if (
            _sender != _account
                && !permissions.hasPermission(_sender, _account, _projectId, _permissionId)
                && !permissions.hasPermission(_sender, _account, 0, _permissionId)
        ) revert UNAUTHORIZED();
    }

    /// @notice If the override condition is truthy, proceed. Otherwise, require the message sender to be the account or have the relevant permission.
    /// @param _account The account to allow.
    /// @param _projectId The project ID to check the permission under.
    /// @param _permissionId The required permission ID. The operator must have this permission within the specified project ID.
    /// @param _override An override condition which will allow access regardless of permissions.
    function _requirePermissionAllowingOverride(
        address _account,
        uint256 _projectId,
        uint256 _permissionId,
        bool _override
    ) internal view {
        if (_override) return;
        _requirePermission(_account, _projectId, _permissionId);
    }
}
