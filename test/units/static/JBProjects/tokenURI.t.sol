// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBProjectsSetup} from "./JBProjectsSetup.sol";

contract TestTokenURI_Local is JBProjectsSetup {
    function setUp() public {
        super.projectsSetup();
    }

    function test_WhenTheresNoResolver() external {
        // it will return empty string
    }

    function test_WhenTheresAResolver() external {
        // it will return the resolved URI
    }
}
