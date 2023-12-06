// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBPermissionsData} from "./../structs/JBPermissionsData.sol";

interface IJBPermissions {
    event OperatorPermissionsSet(
        address indexed operator,
        address indexed account,
        uint256 indexed projectId,
        uint256[] permissionIds,
        uint256 packed,
        address caller
    );

    function permissionsOf(address operator, address account, uint256 projectId)
        external
        view
        returns (uint256);

    function hasPermission(
        address operator,
        address account,
        uint256 projectId,
        uint256 permissionId
    ) external view returns (bool);

    function hasPermissions(
        address operator,
        address account,
        uint256 projectId,
        uint256[] calldata permissionIds
    ) external view returns (bool);

    function setPermissionsForOperator(address account, JBPermissionsData calldata operatorData)
        external;
}
