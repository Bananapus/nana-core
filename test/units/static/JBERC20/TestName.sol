// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBERC20Setup} from "./JBERC20Setup.sol";

contract TestName_Local is JBERC20Setup {
    IERC20Metadata _token;

    function setUp() public {
        super.erc20Setup();

        _token = IERC20Metadata(address(_erc20));
    }

    function test_WhenANameIsSet() external {
        // it will return the name
        _erc20.initialize("NANAPUS", "NANA", _owner);

        string memory _setName = _token.name();
        assertEq(_setName, "NANAPUS");
    }

    function test_WhenANameIsNotSet() external {
        // it will return an empty string

        string memory _storedName = _token.name();
        assertEq(_storedName, "");
    }
}
