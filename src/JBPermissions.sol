// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";

import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {JBPermissionsData} from "./structs/JBPermissionsData.sol";

/// @notice Stores permissions for all addresses and operators. Addresses can give permissions to any other address
/// (i.e. an *operator*) to execute specific operations on their behalf.
contract JBPermissions is IJBPermissions {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error JBPermissions_PermissionIdOutOfBounds();
    error JBPermissions_Unauthorized();

    //*********************************************************************//
    // ------------------------- public constants ------------------------ //
    //*********************************************************************//

    /// @notice The project ID considered a wildcard, meaning it will grant permissions to all projects.
    uint256 public constant override WILDCARD_PROJECT_ID = 0;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The permissions that an operator has been given by an account for a specific project.
    /// @dev An account can give an operator permissions that only pertain to a specific project ID.
    /// @dev There is no project with a ID of 0 – this ID is a wildcard which gives an operator permissions pertaining
    /// to *all* project IDs on an account's behalf. Use this with caution.
    /// @dev Permissions are stored in a packed `uint256`. Each of the 256 bits represents the on/off state of a
    /// permission. Applications can specify the significance of each permission ID.
    /// @custom:param operator The address of the operator.
    /// @custom:param account The address of the account being operated on behalf of.
    /// @custom:param projectId The project ID the permissions are scoped to. An ID of 0 grants permissions across all
    /// projects.
    mapping(address operator => mapping(address account => mapping(uint256 projectId => uint256))) public override
        permissionsOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Check if an operator has a specific permission for a specific address and project ID.
    /// @param operator The operator to check.
    /// @param account The account being operated on behalf of.
    /// @param projectId The project ID that the operator has permission to operate under. 0 represents all projects.
    /// @param permissionId The permission ID to check for.
    /// @param includeRoot A flag indicating if the return value should default to true if the operator has the ROOT
    /// permission.
    /// @param includeWildcardProjectId A flag indicating if the return value should return true if the operator has the
    /// specified permission on the wildcard project ID.
    /// true.
    /// @return A flag indicating whether the operator has the specified permission.
    function hasPermission(
        address operator,
        address account,
        uint256 projectId,
        uint256 permissionId,
        bool includeRoot,
        bool includeWildcardProjectId
    )
        public
        view
        override
        returns (bool)
    {
        // Indexes above 255 don't exist
        if (permissionId > 255) revert JBPermissions_PermissionIdOutOfBounds();

        // If the ROOT permission is set and should be included, return true.
        if (
            includeRoot
                && (
                    _includesPermission({
                        permissions: permissionsOf[operator][account][projectId],
                        permissionId: JBPermissionIds.ROOT
                    })
                        || (
                            includeWildcardProjectId
                                && _includesPermission({
                                    permissions: permissionsOf[operator][account][WILDCARD_PROJECT_ID],
                                    permissionId: JBPermissionIds.ROOT
                                })
                        )
                )
        ) {
            return true;
        }

        // Otherwise return the t/f flag of the specified id.
        return _includesPermission({
            permissions: permissionsOf[operator][account][projectId],
            permissionId: permissionId
        })
            || (
                includeWildcardProjectId
                    && _includesPermission({
                        permissions: permissionsOf[operator][account][WILDCARD_PROJECT_ID],
                        permissionId: permissionId
                    })
            );
    }

    /// @notice Check if an operator has all of the specified permissions for a specific address and project ID.
    /// @param operator The operator to check.
    /// @param account The account being operated on behalf of.
    /// @param projectId The project ID that the operator has permission to operate under. 0 represents all projects.
    /// @param permissionIds An array of permission IDs to check for.
    /// @param includeRoot A flag indicating if the return value should default to true if the operator has the ROOT
    /// permission.
    /// @param includeWildcardProjectId A flag indicating if the return value should return true if the operator has the
    /// specified permission on the wildcard project ID.
    /// @return A flag indicating whether the operator has all specified permissions.
    function hasPermissions(
        address operator,
        address account,
        uint256 projectId,
        uint256[] calldata permissionIds,
        bool includeRoot,
        bool includeWildcardProjectId
    )
        external
        view
        override
        returns (bool)
    {
        // If the ROOT permission is set and should be included, return true.
        if (
            includeRoot
                && (
                    _includesPermission({
                        permissions: permissionsOf[operator][account][projectId],
                        permissionId: JBPermissionIds.ROOT
                    })
                        || (
                            includeWildcardProjectId
                                && _includesPermission({
                                    permissions: permissionsOf[operator][account][WILDCARD_PROJECT_ID],
                                    permissionId: JBPermissionIds.ROOT
                                })
                        )
                )
        ) {
            return true;
        }

        // Keep a reference to the permission being iterated on.
        uint256 permissionId;

        // Keep a reference to the permission item being checked.
        uint256 operatorAccountProjectPermissions = permissionsOf[operator][account][projectId];

        // Keep a reference to the wildcard project permissions.
        uint256 operatorAccountWildcardProjectPermissions =
            includeWildcardProjectId ? permissionsOf[operator][account][WILDCARD_PROJECT_ID] : 0;

        for (uint256 i; i < permissionIds.length; i++) {
            // Set the permission being iterated on.
            permissionId = permissionIds[i];

            // Indexes above 255 don't exist
            if (permissionId > 255) revert JBPermissions_PermissionIdOutOfBounds();

            // Check each permissionId
            if (
                !_includesPermission({permissions: operatorAccountProjectPermissions, permissionId: permissionId})
                    && !_includesPermission({permissions: operatorAccountWildcardProjectPermissions, permissionId: permissionId})
            ) {
                return false;
            }
        }
        return true;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @notice Checks if a permission is included in a packed permissions data.
    /// @param permissions The packed permissions to check.
    /// @param permissionId The ID of the permission to check for.
    /// @return A flag indicating whether the permission is included.
    function _includesPermission(uint256 permissions, uint256 permissionId) internal pure returns (bool) {
        return ((permissions >> permissionId) & 1) == 1;
    }

    /// @notice Converts an array of permission IDs to a packed `uint256`.
    /// @param permissionIds The IDs of the permissions to pack.
    /// @return packed The packed value.
    function _packedPermissions(uint8[] calldata permissionIds) internal pure returns (uint256 packed) {
        // Keep a reference to the permission being iterated on.
        uint256 permissionId;

        for (uint256 i; i < permissionIds.length; i++) {
            // Set the permission being iterated on.
            permissionId = permissionIds[i];

            // Turn on the bit at the ID.
            packed |= 1 << permissionId;
        }
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets permissions for an operator.
    /// @dev Only an address can give permissions to or revoke permissions from its operators.
    /// @param account The account setting its operators' permissions.
    /// @param permissionsData The data which specifies the permissions the operator is being given.
    function setPermissionsFor(address account, JBPermissionsData calldata permissionsData) external override {
        // Pack the permission IDs into a uint256.
        uint256 packed = _packedPermissions(permissionsData.permissionIds);

        // Enforce permissions. ROOT operators are allowed to set permissions so long as they are not setting another
        // ROOT permission.
        if (
            msg.sender != account
                && (
                    _includesPermission({permissions: packed, permissionId: JBPermissionIds.ROOT})
                        || !hasPermission({
                            operator: msg.sender,
                            account: account,
                            projectId: permissionsData.projectId,
                            permissionId: JBPermissionIds.ROOT,
                            includeRoot: true,
                            includeWildcardProjectId: true
                        })
                )
        ) revert JBPermissions_Unauthorized();

        // Store the new value.
        permissionsOf[permissionsData.operator][account][permissionsData.projectId] = packed;

        emit OperatorPermissionsSet({
            operator: permissionsData.operator,
            account: account,
            projectId: permissionsData.projectId,
            permissionIds: permissionsData.permissionIds,
            packed: packed,
            caller: msg.sender
        });
    }
}
