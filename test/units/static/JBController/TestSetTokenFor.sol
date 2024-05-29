// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestSetTokenFor_Local is JBControllerSetup {
    IJBToken _token = IJBToken(makeAddr("token"));
    uint256 _projectId = 1;

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsPermissioned() external {
        // it will set token

        // mock ownerOf call to auth this contract (caller)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(this));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock call to JBTokens
        bytes memory _tokensCall = abi.encodeCall(IJBTokens.setTokenFor, (_projectId, _token));
        mockExpect(address(tokens), _tokensCall, "");

        _controller.setTokenFor(_projectId, _token);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED

        // mock ownerOf call as not this address (unauth)
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _ownerOfReturn = abi.encode(address(0));
        mockExpect(address(projects), _ownerOfCall, _ownerOfReturn);

        // mock permissions call as unauth
        bytes memory _permsCall1 = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), address(0), 1, JBPermissionIds.SET_TOKEN, true, true)
        );
        bytes memory _permsCallReturn1 = abi.encode(false);
        mockExpect(address(permissions), _permsCall1, _permsCallReturn1);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _controller.setTokenFor(_projectId, _token);
    }
}
