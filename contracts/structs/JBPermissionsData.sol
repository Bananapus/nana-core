// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @custom:member operator The address that permissions are being given to.
/// @custom:member projectId The ID of the project the operator is being given permissions for. Operators only have permissions under this project's scope. An ID of 0 is a wildcard, which gives an operator permissions across all projects.
/// @custom:member permissionIds The IDs of the permissions being given. See the `JBPermissionIds` library.
struct JBPermissionsData {
    address operator;
    uint256 projectId;
    uint256[] permissionIds;
}
