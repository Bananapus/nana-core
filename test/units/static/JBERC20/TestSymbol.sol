// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBERC20Setup} from "./JBERC20Setup.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/Extensions/IERC20Metadata.sol";

contract TestSymbol_Local is JBERC20Setup {
    IERC20Metadata _token;

    function setUp() public {
        super.erc20Setup();

        _token = IERC20Metadata(address(_erc20));
    }

    function test_WhenASymbolIsSet() external {
        // it will return a non-empty string

        _erc20.initialize("NANAPUS", "NANA", _owner);

        string memory _setSymbol = _token.symbol();
        assertEq(_setSymbol, "NANA");
    }

    function test_WhenASymbolIsNotSet() external {
        // it will return an empty string

        string memory _setSymbol = _token.symbol();
        assertEq(_setSymbol, "");
    }
}
