// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBPermissionsSetup} from "./JBPermissionsSetup.sol";

contract TestSetPermissionsFor_Local is JBPermissionsSetup {
    address _op = makeAddr("operator");
    address _account = makeAddr("account");
    uint256 _projectId = 1;

    function setUp() public {
        super.permissionsSetup();
    }

    function test_WhenCallerDoesNotHavePermission() external {
        // it will revert UNAUTHORIZED
        JBPermissionsData memory emptyData;

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _permissions.setPermissionsFor(_account, emptyData);
    }

    function test_WhenCallerHasPermission() external {
        // it packs permissions into a bitfield, stores them, and emits OperatorPermissionsSet

        // used to set our root privelage and act as our counter case later
        uint256 permissions = 1 << 1;

        // Find the storage slot
        bytes32 permissionsOfSlot = keccak256(abi.encode(_op, uint256(0)));
        bytes32 accountSlot = keccak256(abi.encode(_account, uint256(permissionsOfSlot)));
        bytes32 slot = keccak256(abi.encode(_projectId, accountSlot));

        // Set storage: this contract can set permissions as ROOT
        vm.store(address(_permissions), slot, bytes32(permissions));

        uint256[] memory array = new uint256[](3);
        array[0] = 1;
        array[1] = 2;
        array[2] = 3;

        JBPermissionsData memory data = JBPermissionsData({operator: _op, projectId: _projectId, permissionIds: array});

        // call it
        vm.prank(_account);
        _permissions.setPermissionsFor(_account, data);

        // permissions that were set during the call
        uint256 afterSet = _permissions.permissionsOf(_op, _account, _projectId);

        // add missing permissions to our counter case "permissions" which we used to assign root access earlier
        permissions |= 1 << 2;
        permissions |= 1 << 3;

        assertEq(afterSet, permissions);
    }

    function test_WhenSettingPermissionOOB() external {
        // it will revert PERMISSION_ID_OUT_OF_BOUNDS()

        // used to set our root privelage and act as our counter case later
        uint256 permissions = 1 << 1;

        // Find the storage slot
        bytes32 permissionsOfSlot = keccak256(abi.encode(_op, uint256(0)));
        bytes32 accountSlot = keccak256(abi.encode(_account, uint256(permissionsOfSlot)));
        bytes32 slot = keccak256(abi.encode(_projectId, accountSlot));

        // Set storage: this contract can set permissions as ROOT
        vm.store(address(_permissions), slot, bytes32(permissions));

        uint256[] memory array = new uint256[](1);
        array[0] = 256;

        JBPermissionsData memory data = JBPermissionsData({operator: _op, projectId: _projectId, permissionIds: array});

        // call it
        vm.prank(_account);

        vm.expectRevert(abi.encodeWithSignature("PERMISSION_ID_OUT_OF_BOUNDS()"));
        _permissions.setPermissionsFor(_account, data);

        /* // permissions that were set during the call
        uint256 afterSet = _permissions.permissionsOf(_op, _account, _projectId);

        // add missing permissions to our counter case "permissions" which we used to assign root access earlier
        permissions |= 1 << 2;
        permissions |= 1 << 3;

        assertEq(afterSet, permissions); */
    }
}
