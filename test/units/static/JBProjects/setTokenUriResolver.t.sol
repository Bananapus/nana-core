// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBProjectsSetup} from "./JBProjectsSetup.sol";

contract TestSetTokenURIResolver_Local is JBProjectsSetup {
    function setUp() public {
        super.projectsSetup();
    }

    function test_WhenCallerIsOwner() external {
        // it will set resolver and emit SetTokenUriResolver
    }

    function test_WhenCallerIsNotOwner() external {
        // it will revert
    }
}
