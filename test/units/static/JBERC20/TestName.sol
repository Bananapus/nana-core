// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBERC20Setup} from "./JBERC20Setup.sol";

contract TestName_Local is JBERC20Setup {

    function setUp() public {
        super.erc20Setup();
    }

    function test_WhenANameIsSet() external {
        // it will return the name
    }

    function test_WhenANameIsNotSet() external {
        // it will return an empty string
    }
}
