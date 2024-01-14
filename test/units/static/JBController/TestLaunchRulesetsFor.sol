// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestLaunchRulesetsFor_Local is JBTest, JBControllerSetup {

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier whenCallerWithoutPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock permission call
        bytes memory _call = abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.QUEUE_RULESETS));
        mockExpect(address(permissions), _call, abi.encode(false));

        // mock permission call #2 (checks for root priv)
        bytes memory _call2 = abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(1), 0, JBPermissionIds.QUEUE_RULESETS));
        mockExpect(address(permissions), _call2, abi.encode(false));
        _;
    }

    function setUp() public {
        super.controllerSetup();
    }

    function test_RevertWhen_CallerDoesNotHavePermission() whenCallerWithoutPermission external {
        // it should revert
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](0);

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_Revert_GivenTheProjectAlreadyHasRulesets() external whenCallerHasPermission {
        // it should revert
        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](0);

        bytes memory _latestRulesetIdOfCall = abi.encodeCall(IJBRulesets.latestRulesetIdOf, (1));
        bytes memory _returnData = abi.encode(1);

        mockExpect(address(rulesets), _latestRulesetIdOfCall, _returnData);

        vm.expectRevert(abi.encodeWithSignature("RULESET_ALREADY_LAUNCHED()"));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }

    function test_GivenTheProjectDoesNotYetHaveRulesets() external whenCallerHasPermission {
        // it should set the controller, queue the rulesets, configure terminals, and emit LaunchRulesets

        JBTerminalConfig[] memory _terminalConfigs = new JBTerminalConfig[](0);
        JBRulesetConfig[] memory _rulesetConfigs = new JBRulesetConfig[](0);

        // mock call to latest rulesets
        bytes memory _latestRulesetIdOfCall = abi.encodeCall(IJBRulesets.latestRulesetIdOf, (1));
        bytes memory _returnData = abi.encode(0);

        mockExpect(address(rulesets), _latestRulesetIdOfCall, _returnData);

        // mock call to setControllerOf
        bytes memory _setControllerCall = abi.encodeCall(IJBDirectory.setControllerOf, (1, IERC165(address(_controller))));
        bytes memory _setReturn = abi.encode();

        mockExpect(address(directory), _setControllerCall, _setReturn);

        // event as expected
        vm.expectEmit();
        emit IJBController.LaunchRulesets(0, 1, "", address(this));

        _controller.launchRulesetsFor(1, _rulesetConfigs, _terminalConfigs, "");
    }
}
