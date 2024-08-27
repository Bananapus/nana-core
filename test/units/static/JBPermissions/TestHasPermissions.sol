// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPermissionsSetup} from "./JBPermissionsSetup.sol";

contract TestHasPermissions_Local is JBPermissionsSetup {
    address _op = makeAddr("operator");
    address _account = makeAddr("account");
    uint256 _projectId = 1;
    uint256[] _permissionsArray = [256, 256];

    function setUp() public {
        super.permissionsSetup();
    }

    function test_WhenAnyPermissionIdGt255() external {
        // it will revert with PERMISSION_ID_OUT_OF_BOUNDS
        vm.expectRevert(abi.encodeWithSelector(JBPermissions.JBPermissions_PermissionIdOutOfBounds.selector, 256));
        _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, true, true);
    }

    modifier whenAllPermissionIdsLt255() {
        _permissionsArray = [1, 2, 3];
        _;
    }

    function test_GivenOperatorDoesNotHaveAllPermissionsSpecified() external whenAllPermissionIdsLt255 {
        // it will return false
        uint256 permissions = 1 << 1;

        // Find the storage slot
        bytes32 permissionsOfSlot = keccak256(abi.encode(_op, uint256(0)));
        bytes32 accountSlot = keccak256(abi.encode(_account, uint256(permissionsOfSlot)));
        bytes32 slot = keccak256(abi.encode(_projectId, accountSlot));

        // Set storage
        vm.store(address(_permissions), slot, bytes32(permissions));

        bool hasAll = _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, false, true);
        assertEq(hasAll, false);
    }

    function test_GivenOperatorHasAllPermissionsSpecified() external whenAllPermissionIdsLt255 {
        // it will return true
        uint256 permissions = 1 << 1;
        permissions |= 1 << 2;
        permissions |= 1 << 3;

        // Find the storage slot
        bytes32 permissionsOfSlot = keccak256(abi.encode(_op, uint256(0)));
        bytes32 accountSlot = keccak256(abi.encode(_account, uint256(permissionsOfSlot)));
        bytes32 slot = keccak256(abi.encode(_projectId, accountSlot));

        // Set storage
        vm.store(address(_permissions), slot, bytes32(permissions));

        bool hasAll = _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, false, false);
        assertEq(hasAll, true);
    }

    function test_GivenOperatorHasAllPermissionsSpecifiedCounterCase() external whenAllPermissionIdsLt255 {
        // it will return false
        uint256 permissions = 1 << 1;
        permissions |= 1 << 5;
        permissions |= 1 << 7;

        // Find the storage slot
        bytes32 permissionsOfSlot = keccak256(abi.encode(_op, uint256(0)));
        bytes32 accountSlot = keccak256(abi.encode(_account, uint256(permissionsOfSlot)));
        bytes32 slot = keccak256(abi.encode(_projectId, accountSlot));

        // Set storage
        vm.store(address(_permissions), slot, bytes32(permissions));

        bool hasAll = _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, true, true);
        bool hasAll2 = _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, false, false);
        bool hasAll3 = _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, true, false);
        bool hasAll4 = _permissions.hasPermissions(_op, _account, _projectId, _permissionsArray, false, true);

        // True as it includes root
        assertEq(hasAll, true);

        // Does not include root
        assertEq(hasAll2, false);

        // True as it includes root
        assertEq(hasAll3, true);

        // Does not include root
        assertEq(hasAll4, false);
    }
}
