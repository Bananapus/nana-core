// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBERC20Setup} from "./JBERC20Setup.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestInitialize_Local is JBERC20Setup {
    string _name = "Nana";
    string _symbol = "NANA";

    function setUp() public {
        super.erc20Setup();
    }

    function test_WhenANameIsAlreadySet() external {
        // it will revert

        _erc20.initialize(_name, _symbol, _owner);

        // ensure ownership transferred
        address newOwner = Ownable(address(_erc20)).owner();
        assertEq(newOwner, _owner);

        // will fail as internal name is no longer zero length
        vm.expectRevert();
        _erc20.initialize(_name, _symbol, _owner);
    }

    function test_WhenName_EQNothing() external {
        // it will revert
    }

    function test_WhenNameIsValidAndNotAlreadySet() external {
        // it will set the name and symbol and transfer ownership
    }
}
