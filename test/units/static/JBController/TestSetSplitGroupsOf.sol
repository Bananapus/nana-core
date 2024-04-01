// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSetSplitGroupsOf_Local is JBControllerSetup {
    uint256 _projectId = 1;
    uint256 _rulesetId = block.timestamp;

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsPermissioned() external {
        // it will call JBSplits and "set splits"

        // data for calls
        JBSplitGroup[] memory _splitGroups = new JBSplitGroup[](0);

        // mock call to JBProjects ownerOf for permission check
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(this));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock call to JBSplits setSplitGroupsOf
        bytes memory _setSplitsCall = abi.encodeCall(IJBSplits.setSplitGroupsOf, (_projectId, _rulesetId, _splitGroups));
        mockExpect(address(splits), _setSplitsCall, "");

        _controller.setSplitGroupsOf(_projectId, _rulesetId, _splitGroups);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED

        // data for calls
        JBSplitGroup[] memory _splitGroups = new JBSplitGroup[](0);

        // mock call to JBProjects ownerOf for permission check
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(0));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock call to JBPermissions
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), address(0), _projectId, JBPermissionIds.SET_SPLIT_GROUPS)
        );
        bytes memory _permReturn = abi.encode(false);
        mockExpect(address(permissions), _permCall, _permReturn);

        // mock call to JBPermissions that checks root
        bytes memory _permCall2 = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), address(0), 0, JBPermissionIds.SET_SPLIT_GROUPS)
        );
        bytes memory _permReturn2 = abi.encode(false);
        mockExpect(address(permissions), _permCall2, _permReturn2);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _controller.setSplitGroupsOf(_projectId, _rulesetId, _splitGroups);
    }
}
