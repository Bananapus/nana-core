// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBProjectsSetup} from "./JBProjectsSetup.sol";

contract TestSetTokenURIResolver_Local is JBProjectsSetup {
    IJBTokenUriResolver _resolver = IJBTokenUriResolver(makeAddr("uri"));

    function setUp() public {
        super.projectsSetup();
    }

    function test_WhenCallerIsOwner() external {
        // it will set resolver and emit SetTokenUriResolver

        // expect call from owner since we prank
        vm.expectEmit();
        emit IJBProjects.SetTokenUriResolver(_resolver, _owner);

        vm.prank(_owner);
        _projects.setTokenUriResolver(_resolver);
    }

    function test_WhenCallerIsNotOwner() external {
        // it will revert

        // encode custom error
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        bytes memory expectedError = abi.encodeWithSelector(selector, address(this));

        vm.expectRevert(expectedError);

        _projects.setTokenUriResolver(_resolver);
    }
}
