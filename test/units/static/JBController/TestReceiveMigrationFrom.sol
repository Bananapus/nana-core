// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestReceiveMigrationFrom_Local is JBControllerSetup {
    uint256 _projectId = 1;
    IERC165 _from = IERC165(makeAddr("from"));

    function setUp() public {
        super.controllerSetup();
    }

    function test_GivenThatTheCallerIsAlsoControllerOfProjectId() external {
        vm.expectRevert(
            abi.encodeWithSelector(JBController.JBController_OnlyDirectory.selector, address(this), address(directory))
        );

        vm.prank(address(this));
        IJBMigratable(address(_controller)).beforeReceiveMigrationFrom(_from, _projectId);
    }

    function test_GivenThatTheCallerIsDirectory() external {
        // mock supports interface call
        mockExpect(
            address(_from),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBProjectUriRegistry).interfaceId)),
            abi.encode(true)
        );

        // mock call to from uriOf
        mockExpect(address(_from), abi.encodeCall(IJBProjectUriRegistry.uriOf, (_projectId)), abi.encode("Juicay"));

        vm.prank(address(directory));
        IJBMigratable(address(_controller)).beforeReceiveMigrationFrom(_from, _projectId);
        string memory stored = _controller.uriOf(_projectId);
        assertEq(stored, "Juicay");
    }

    function test_GivenThatTheCallerIsNotController() external {
        // it will revert

        vm.expectRevert(
            abi.encodeWithSelector(JBController.JBController_OnlyDirectory.selector, address(this), address(directory))
        );
        IJBMigratable(address(_controller)).beforeReceiveMigrationFrom(_from, _projectId);
    }
}
