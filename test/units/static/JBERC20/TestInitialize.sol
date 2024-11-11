// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBERC20Setup} from "./JBERC20Setup.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestInitialize_Local is JBERC20Setup {
    string _name = "Nana";
    string _symbol = "NANA";
    uint256 _projectId = 1;

    function setUp() public {
        super.erc20Setup();
    }

    function test_WhenANameIsAlreadySet() external {
        // it will revert

        _erc20.initialize(_name, _symbol, _projectId, _owner);

        // ensure ownership transferred
        address newOwner = Ownable(address(_erc20)).owner();
        assertEq(newOwner, _owner);

        // will fail as internal name is no longer zero length
        vm.expectRevert();
        _erc20.initialize(_name, _symbol, _projectId, _owner);
    }

    function test_WhenName_EQNothing() external {
        // it will revert

        // will fail as internal name is no longer than zero length
        vm.expectRevert();
        _erc20.initialize("", _symbol, _projectId, _owner);
    }

    function test_WhenNameIsValidAndNotAlreadySet() external {
        // it will set the name and symbol and transfer ownership

        _erc20.initialize(_name, _symbol, _projectId, _owner);

        // ensure ownership transferred
        address newOwner = Ownable(address(_erc20)).owner();
        assertEq(newOwner, _owner);

        // name is set
        string memory _setName = IERC20Metadata(address(_erc20)).name();
        string memory _setSymbol = IERC20Metadata(address(_erc20)).symbol();

        assertEq(_setName, _name);
        assertEq(_setSymbol, _symbol);
    }
}
