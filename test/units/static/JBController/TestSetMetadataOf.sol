// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSetMetadataOf_Local is JBControllerSetup {
    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsOwnerOrHasPermission() external {
        // it should set metadata and emit SetMetadata
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        vm.expectEmit();
        emit IJBController.SetMetadata(1, "Juicay", address(this));

        _controller.setUriOf(1, "Juicay");
    }

    function test_RevertWhenCallerIsNotOwnerOrHasPermission() external {
        // it should revert
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock first permissions call
        bytes memory _permissionsCall = abi.encodeCall(
            IJBPermissions.hasPermission,
            (address(this), address(1), 1, JBPermissionIds.SET_PROJECT_METADATA, true, true)
        );
        bytes memory _permissionsReturned = abi.encode(false);

        mockExpect(address(permissions), _permissionsCall, _permissionsReturned);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _controller.setUriOf(1, "Not Juicay");
    }
}
