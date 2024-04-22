// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBERC20Setup} from "./JBERC20Setup.sol";

contract TestNonces_Local is JBERC20Setup {
    function setUp() public {
        super.erc20Setup();
    }

    function test_WhenAUserHasNotCalledPermit() external {
        // it will return zero
    }

    function test_WhenAUserHasCalledPermit() external {
        // it will return a nonce GT zero
    }
}
