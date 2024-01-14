// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestLaunchRulesetsFor_Local is JBTest, JBControllerSetup {

    function setUp() public {
        super.controllerSetup();
    }

    function test_RevertWhen_CallerDoesNotHavePermission() external {
        // it should revert
    }

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        /* // mock permission call
        bytes memory _call = abi.encodeCall(IJBPermissions.hasPermission, (address(this), address(this), 1, JBPermissionIds.QUEUE_RULESETS));

        mockExpect(address(permissions), _call, ""); */
        _;
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

    /* function test_GivenTheProjectDoesNotYetHaveRulesets() external whenCallerHasPermission {
        // it should set the controller, queue the rulesets, configure terminals, and emit LaunchRulesets
    } */
}
