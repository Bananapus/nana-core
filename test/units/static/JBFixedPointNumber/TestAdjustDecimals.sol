// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFixedPointNumber} from "../../../../src/libraries/JBFixedPointNumber.sol";

contract TestAdjustDecimals_Local is JBTest {
    function setUp() external {}

    function testWhenTargetEqDecimals() external {
        // it will return the value parameter provided

        uint256 returned = JBFixedPointNumber.adjustDecimals(1e18, 6, 6);
        assertEq(returned, 1e18);
    }
}
