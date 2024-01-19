// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetPrimaryTerminalOf_Local is JBTest, JBDirectorySetup {
    using stdStorage for StdStorage;

    IJBTerminal _terminalToAdd = IJBTerminal(makeAddr("newTerminal"));
    address _token = makeAddr("newToken");

    function setUp() public {
        super.directorySetup();
    }

    modifier givenThatTheTerminalHasNotBeenAdded() {
        vm.expectEmit();
        emit IJBDirectory.AddTerminal(1, _terminalToAdd, address(this));
        _;
    }

    modifier givenThatTheTerminalHasBeenAdded() {
        _;
    }

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier givenThatThereIsAnAccountingContextForTokenOf() {
        // accounting context
        JBAccountingContext memory _context = JBAccountingContext({token: _token, decimals: 6, currency: uint32(1)});

        // mock accountingContext call
        bytes memory _contextCall = abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (1, _token));
        bytes memory _contextReturn = abi.encode(_context);

        mockExpect(address(_terminalToAdd), _contextCall, _contextReturn);
        _;
    }

    /* function test_WhenCallerHasNoPermission() external {
        // it should revert with UNAUTHORIZED()
    }

    function test_GivenThatThereIsNoAccountingContextForTokenOf() external whenCallerHasPermission {
        // it should revert with TOKEN_NOT_ACCEPTED
    }

    function test_GivenThatTheTerminalHasAlreadyBeenAdded()
        external
        whenCallerHasPermission
        givenThatThereIsAnAccountingContextForTokenOf
    {
        // it should not add the terminal
    }

    function test_GivenThatTheProjectIsNotAllowedToSetTerminals()
        external
        whenCallerHasPermission
        givenThatThereIsAnAccountingContextForTokenOf
        givenThatTheTerminalHasNotBeenAdded
    {
        // it should revert with SET_TERMINALS_NOT_ALLOWED
    } */

    function test_GivenThatTheProjectIsAllowedToSetTerminals()
        external
        whenCallerHasPermission
        givenThatThereIsAnAccountingContextForTokenOf
        givenThatTheTerminalHasNotBeenAdded
    {
        // it should set the terminal and emit AddTerminal
        // it should set the terminal as primary and emit SetPrimaryTerminal

        address _mockController = makeAddr("controller");

        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(
            _mockController
        );
        // mock erc165 call
        bytes memory _supportCall =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId));
        bytes memory _supportReturned = abi.encode(false);

        mockExpect(address(_mockController), _supportCall, _supportReturned);

        /* vm.prank(_mockController); */
        _directory.setPrimaryTerminalOf(1, _token, _terminalToAdd);
    }
}
