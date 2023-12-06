// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {JBPermissionIds} from "./libraries/JBPermissionIds.sol";
import {JBPermissionsData} from "./structs/JBPermissionsData.sol";

/// @notice Stores permissions for all addresses and operators. Addresses can give permissions to any other address (i.e. an *operator*) to execute specific operations on their behalf.
contract JBPermissions is JBPermissioned, IJBPermissions {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error PERMISSION_ID_OUT_OF_BOUNDS();

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The permissions that an operator has been given by an account for a specific project.
    /// @dev An account can give an operator permissions that only pertain to a specific project ID.
    /// @dev There is no project with a ID of 0 – this ID is a wildcard which gives an operator permissions pertaining to *all* project IDs on an account's behalf. Use this with caution.
    /// @dev Permissions are stored in a packed `uint256`. Each of the 256 bits represents the on/off state of a permission. Applications can specify the significance of each permission ID.
    /// @custom:param _operator The address of the operator.
    /// @custom:param _account The address of the account being operated on behalf of.
    /// @custom:param _projectId The project ID the permissions are scoped to. An ID of 0 grants permissions across all projects.
    mapping(address => mapping(address => mapping(uint256 => uint256))) public override
        permissionsOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Check if an operator has a specific permission for a specific address and project ID.
    /// @param _operator The operator to check.
    /// @param _account The account being operated on behalf of.
    /// @param _projectId The project ID that the operator has permission to operate under. 0 represents all projects.
    /// @param _permissionId The permission ID to check for.
    /// @return A flag indicating whether the operator has the specified permission.
    function hasPermission(
        address _operator,
        address _account,
        uint256 _projectId,
        uint256 _permissionId
    ) external view override returns (bool) {
        if (_permissionId > 255) revert PERMISSION_ID_OUT_OF_BOUNDS();

        return (((permissionsOf[_operator][_account][_projectId] >> _permissionId) & 1) == 1);
    }

    /// @notice Check if an operator has all of the specified permissions for a specific address and project ID.
    /// @param _operator The operator to check.
    /// @param _account The account being operated on behalf of.
    /// @param _projectId The project ID that the operator has permission to operate under. 0 represents all projects.
    /// @param _permissionIds An array of permission IDs to check for.
    /// @return A flag indicating whether the operator has all specified permissions.
    function hasPermissions(
        address _operator,
        address _account,
        uint256 _projectId,
        uint256[] calldata _permissionIds
    ) external view override returns (bool) {
        // Keep a reference to the number of permissions being iterated on.
        uint256 _numberOfPermissions = _permissionIds.length;

        for (uint256 _i; _i < _numberOfPermissions;) {
            uint256 _permissionId = _permissionIds[_i];

            if (_permissionId > 255) revert PERMISSION_ID_OUT_OF_BOUNDS();

            if (((permissionsOf[_operator][_account][_projectId] >> _permissionId) & 1) == 0) {
                return false;
            }

            unchecked {
                ++_i;
            }
        }
        return true;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    constructor() JBPermissioned(this) {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets permissions for an operator.
    /// @dev Only an address can give permissions to or revoke permissions from its operators.
    /// @param _account The account setting its operators' permissions.
    /// @param _permissionsData The data which specifies the permissions the operator is being given.
    function setPermissionsForOperator(
        address _account,
        JBPermissionsData calldata _permissionsData
    )
        external
        override
        requirePermission(_account, _permissionsData.projectId, JBPermissionIds.ROOT)
    {
        // Pack the permission IDs into a uint256.
        uint256 _packed = _packedPermissions(_permissionsData.permissionIds);

        // Store the new value.
        permissionsOf[_permissionsData.operator][_account][_permissionsData.projectId] = _packed;

        emit OperatorPermissionsSet(
            _permissionsData.operator,
            _account,
            _permissionsData.projectId,
            _permissionsData.permissionIds,
            _packed,
            msg.sender
        );
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice Converts an array of permission IDs to a packed `uint256`.
    /// @param _permissionIds The IDs of the permissions to pack.
    /// @return packed The packed value.
    function _packedPermissions(uint256[] calldata _permissionIds)
        private
        pure
        returns (uint256 packed)
    {
        // Keep a reference to the number of IDs being iterated on.
        uint256 _numberOfIds = _permissionIds.length;

        for (uint256 _i; _i < _numberOfIds;) {
            uint256 _id = _permissionIds[_i];

            if (_id > 255) revert PERMISSION_ID_OUT_OF_BOUNDS();

            // Turn on the bit at the ID.
            packed |= 1 << _id;

            unchecked {
                ++_i;
            }
        }
    }
}
