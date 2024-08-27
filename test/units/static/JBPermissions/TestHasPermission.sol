// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPermissionsSetup} from "./JBPermissionsSetup.sol";

contract TestHasPermissions_Local is JBPermissionsSetup {
    address _op = makeAddr("operator");
    address _account = makeAddr("account");
    uint256 _projectId = 1;
    uint256 _permission = 256;

    function setUp() public {
        super.permissionsSetup();
    }

    function test_WhenPermissionIdGt255() external {
        // it will revert with PERMISSION_ID_OUT_OF_BOUNDS

        vm.expectRevert(abi.encodeWithSelector(JBPermissions.JBPermissions_PermissionIdOutOfBounds.selector, 256));
        _permissions.hasPermission(_op, _account, _projectId, _permission, true, true);
    }

    modifier whenPermissionIdLt255() {
        _permission = 1;
        _;
    }

    function test_GivenOperatorHasPermissionForAccountOfProject() external whenPermissionIdLt255 {
        // it will return true
        uint256 permissions = 1 << 1;

        // Find the storage slot
        bytes32 permissionsOfSlot = keccak256(abi.encode(_op, uint256(0)));
        bytes32 accountSlot = keccak256(abi.encode(_account, uint256(permissionsOfSlot)));
        bytes32 slot = keccak256(abi.encode(_projectId, accountSlot));

        // Set storage
        vm.store(address(_permissions), slot, bytes32(permissions));

        bool has = _permissions.hasPermission(_op, _account, _projectId, 1, true, true);
        assertEq(has, true);
    }

    function test_GivenOperatorDoesntHavePermissionForAccountOfProject() external whenPermissionIdLt255 {
        // it will return false
        bool has = _permissions.hasPermission(_op, _account, _projectId, 1, true, true);
        assertEq(has, false);
    }
}
