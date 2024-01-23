// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFeelessSetup} from "./JBFeelessSetup.sol";

contract TestSetFeelessAddress_Local is JBFeelessSetup {
    function setUp() public {
        super.feelessAddressesSetup();
    }

    function test_WhenCallerIsOwner() external {
        // it should set isFeeless and emit SetFeelessAddress
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        // it should revert
    }
}
