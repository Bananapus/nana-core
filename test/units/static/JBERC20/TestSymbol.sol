// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBERC20Setup} from "./JBERC20Setup.sol";

contract TestSymbol_Local is JBERC20Setup {
    function setUp() public {
        super.erc20Setup();
    }

    function test_WhenASymbolIsSet() external {
        // it will return a non-empty string
    }

    function test_WhenASymbolIsNotSet() external {
        // it will return an empty string
    }
}
