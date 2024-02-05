// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestClaimTokensFor_Local is JBControllerSetup {
    address _holder = makeAddr("hodler");
    uint256 _projectId = 1;
    uint256 _rootId = 0;
    uint256 _amount = 1e18;
    address _beneficiary = makeAddr("bene");

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsPermissioned() external {
        // it should call JBTokens to claim on behalf of holder

        // it will call permissions
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _holder, _projectId, JBPermissionIds.CLAIM_TOKENS)
        );
        bytes memory _permReturn = abi.encode(true);
        mockExpect(address(permissions), _permCall, _permReturn);

        // it will call JBTokens to claim when permissioned
        bytes memory _tokensCall = abi.encodeCall(IJBTokens.claimTokensFor, (_holder, _projectId, _amount, _beneficiary));
        bytes memory _tokensReturn = abi.encode();
        mockExpect(address(tokens), _tokensCall, _tokensReturn);

        // will succeed
        _controller.claimTokensFor(_holder, _projectId, _amount, _beneficiary);
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it should revert UNAUTHORIZED

        // it will call permissions
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _holder, _projectId, JBPermissionIds.CLAIM_TOKENS)
        );
        bytes memory _permReturn = abi.encode(false);
        mockExpect(address(permissions), _permCall, _permReturn);

        // it will call permissions again to check root permission
        bytes memory _permCall2 = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _holder, _rootId, JBPermissionIds.CLAIM_TOKENS)
        );
        bytes memory _permReturn2 = abi.encode(false);
        mockExpect(address(permissions), _permCall2, _permReturn2);

        // will revert
        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _controller.claimTokensFor(_holder, _projectId, _amount, _beneficiary);
    }
}
