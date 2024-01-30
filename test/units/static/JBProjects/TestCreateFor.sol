// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import {JBProjectsSetup} from "./JBProjectsSetup.sol";

contract TestCreateFor_Local is JBProjectsSetup {
    using stdStorage for StdStorage;
    address _user = makeAddr("sudoer");

    function setUp() public {
        super.projectsSetup();
    }

    function test_WhenProjectIdPlusOneIsGtUint256Max() external {
        // it will revert with overflow

        // set storage to uint256 max
        stdstore
        .target(address(_projects))
        .sig("count()")
        .checked_write(type(uint256).max);

        assertEq(_projects.count(), type(uint256).max);

        vm.expectRevert(stdError.arithmeticError);
        _projects.createFor(address(this));
    }

    modifier whenProjectIdPlusOneIsLtOrEqToUint256Max() {
        _;
    }

    function test_GivenOwnerIsNotAContract() external whenProjectIdPlusOneIsLtOrEqToUint256Max {
        // it will mint and emit Create

        // created on behalf of user by this contract
        vm.expectEmit();
        emit IJBProjects.Create(1, _user, address(this));

        _projects.createFor(_user);

        // check count is incrementing 
        assertEq(_projects.count(), 1);
    }

    function test_GivenItIsIERC721Receiver() external whenProjectIdPlusOneIsLtOrEqToUint256Max {
        // it will mint and emit Create

        // mock IERC721Receiver support (return interface selector for onERC721Received)
        bytes memory receiverCall = abi.encodeCall(IERC721Receiver.onERC721Received, (address(this), address(0), 1, bytes("")));
        bytes memory returned = abi.encode(IERC721Receiver.onERC721Received.selector);

        mockExpect(address(this), receiverCall, returned);

        _projects.createFor(address(this));
    }

    function test_GivenItDoesNotSupportIERC721Receiver()
        external
        whenProjectIdPlusOneIsLtOrEqToUint256Max
    {
        // it will revert

        // encode custom error
        bytes4 selector = bytes4(keccak256("ERC721InvalidReceiver(address)"));
        bytes memory expectedError = abi.encodeWithSelector(selector, address(this));

        vm.expectRevert(expectedError);
        _projects.createFor(address(this));
    }
}
