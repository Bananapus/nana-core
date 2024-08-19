// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestBurnTokensOf_Local is JBControllerSetup {
    uint256 _projectId = 1;
    uint256 _rootProjectId = 0;
    uint256 _validCount = 1;
    uint256 _invalidCount = 0;
    string _memo = "JUICAY";
    address _holder = makeAddr("hodl");

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsNotPermissionedOrTerminal() external {
        // it should revert UNAUTHORIZED()

        // it will call directory to check if caller is terminal first
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.isTerminalOf, (1, IJBTerminal(address(this))));
        bytes memory _directoryReturned = abi.encode(false);
        mockExpect(address(directory), _directoryCall, _directoryReturned);

        // it will call permissions after to first check permissions over the specific project
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _holder, _projectId, JBPermissionIds.BURN_TOKENS, true, true)
        );
        bytes memory _permReturn = abi.encode(false);
        mockExpect(address(permissions), _permCall, _permReturn);

        vm.expectRevert(JBPermissioned.JBPermissioned_Unauthorized.selector);
        _controller.burnTokensOf(_holder, _projectId, _validCount, _memo);
    }

    function test_WhenCallerIsTerminalAndTokenCountGtZero() external {
        // it should burn and emit BurnTokens

        // it will call directory to check if caller is terminal first
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.isTerminalOf, (1, IJBTerminal(address(this))));
        bytes memory _directoryReturned = abi.encode(true);
        mockExpect(address(directory), _directoryCall, _directoryReturned);

        // since we spoofed a terminal it will call JBTokens to burn
        bytes memory _burnFromCall = abi.encodeCall(IJBTokens.burnFrom, (_holder, _projectId, _validCount));
        bytes memory _burnFromReturn = "";
        mockExpect(address(tokens), _burnFromCall, _burnFromReturn);

        vm.expectEmit();
        emit IJBController.BurnTokens(_holder, _projectId, _validCount, _memo, address(this));
        _controller.burnTokensOf(_holder, _projectId, _validCount, _memo);
    }

    function test_WhenCallerHasRootPermissionAndTokenCountGtZero() external {
        // it should burn and emit BurnTokens

        // it will call directory to check if caller is terminal first
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.isTerminalOf, (1, IJBTerminal(address(this))));
        bytes memory _directoryReturned = abi.encode(false);
        mockExpect(address(directory), _directoryCall, _directoryReturned);

        // it will call permissions after to first check permissions over the specific project
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _holder, _projectId, JBPermissionIds.BURN_TOKENS, true, true)
        );
        bytes memory _permReturn = abi.encode(true);
        mockExpect(address(permissions), _permCall, _permReturn);

        // it will call JBTokens to burn
        bytes memory _burnFromCall = abi.encodeCall(IJBTokens.burnFrom, (_holder, _projectId, _validCount));
        bytes memory _burnFromReturn = "";
        mockExpect(address(tokens), _burnFromCall, _burnFromReturn);

        vm.expectEmit();
        emit IJBController.BurnTokens(_holder, _projectId, _validCount, _memo, address(this));
        _controller.burnTokensOf(_holder, _projectId, _validCount, _memo);
    }

    function test_WhenTokenCountEqZero() external {
        // it should revert NO_BURNABLE_TOKENS

        // it will call directory to check if caller is terminal first
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.isTerminalOf, (1, IJBTerminal(address(this))));
        bytes memory _directoryReturned = abi.encode(false);
        mockExpect(address(directory), _directoryCall, _directoryReturned);

        // it will call permissions after to first check permissions over the specific project
        bytes memory _permCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), _holder, _projectId, JBPermissionIds.BURN_TOKENS, true, true)
        );
        bytes memory _permReturn = abi.encode(true);
        mockExpect(address(permissions), _permCall, _permReturn);

        vm.expectRevert(JBController.JBController_NoBurnableTokens.selector);
        _controller.burnTokensOf(_holder, _projectId, _invalidCount, _memo);
    }
}
