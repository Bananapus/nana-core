// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestDeployERC20For_Local is JBControllerSetup {
    uint256 _projectId = 1;
    IJBToken _token = IJBToken(makeAddr("token"));
    string _name = "Juice";
    string _symbol = "JCY";
    bytes32 _salt = bytes32(0);

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsPermissioned() external {
        // it will deploy ERC20 and return IJBToken

        // mock call to JBProjects ownerOf which will give permission
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock the call to JBTokens deployERC20For
        bytes memory _deployCall = abi.encodeCall(IJBTokens.deployERC20For, (_projectId, _name, _symbol, _salt));
        bytes memory _deployCallReturn = abi.encode(_token);
        mockExpect(address(tokens), _deployCall, _deployCallReturn);

        _controller.deployERC20For(_projectId, _name, _symbol, _salt);
    }

    function test_WhenCallerIsPermissionedAndSaltIsNonZero() external {
        // it will deploy ERC20 and return IJBToken

        bytes32 _nonZeroSalt = bytes32("somesalt");
        bytes32 _encodedSalt = keccak256(abi.encodePacked(address(this), _nonZeroSalt));

        // mock call to JBProjects ownerOf which will give permission
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock the call to JBTokens deployERC20For
        bytes memory _deployCall = abi.encodeCall(IJBTokens.deployERC20For, (_projectId, _name, _symbol, _encodedSalt));
        bytes memory _deployCallReturn = abi.encode(_token);
        mockExpect(address(tokens), _deployCall, _deployCallReturn);

        _controller.deployERC20For(_projectId, _name, _symbol, _nonZeroSalt);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED

        // mock call to JBProjects ownerOf which will give permission
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        address _projectsCallReturn = address(0);
        mockExpect(address(projects), _projectsCall, abi.encode(_projectsCallReturn));

        // mock call for projects permission
        bytes memory _permissionCall1 = abi.encodeCall(
            IJBPermissions.hasPermission,
            (address(this), address(0), _projectId, JBPermissionIds.DEPLOY_ERC20, true, true)
        );
        bytes memory _permissionCallReturn1 = abi.encode(false);
        mockExpect(address(permissions), _permissionCall1, _permissionCallReturn1);

        vm.expectRevert(
            abi.encodeWithSelector(
                JBPermissioned.JBPermissioned_Unauthorized.selector, _projectsCallReturn, address(this), _projectId, 7
            )
        );
        _controller.deployERC20For(_projectId, _name, _symbol, _salt);
    }
}
