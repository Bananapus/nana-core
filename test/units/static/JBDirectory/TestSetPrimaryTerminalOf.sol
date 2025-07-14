// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetPrimaryTerminalOf_Local is JBDirectorySetup {
    using stdStorage for StdStorage;

    IJBTerminal _terminalToAdd = IJBTerminal(makeAddr("newTerminal"));
    address _mockController = makeAddr("controller");
    address _token = makeAddr("newToken");

    function setUp() public {
        super.directorySetup();
    }

    modifier givenTerminalHasNotBeenAdded() {
        vm.expectEmit();
        emit IJBDirectory.AddTerminal(1, _terminalToAdd, address(this));
        _;
    }

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier givenValidAccountingContext() {
        // accounting context
        JBAccountingContext memory _context = JBAccountingContext({token: _token, decimals: 6, currency: uint32(1)});

        // mock accountingContext call
        bytes memory _contextCall = abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (1, _token));
        bytes memory _contextReturn = abi.encode(_context);

        mockExpect(address(_terminalToAdd), _contextCall, _contextReturn);
        _;
    }

    function test_WhenCallerHasNoMaidens() external {
        // it should revert with UNAUTHORIZED()
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        address _ownerData = address(1);

        mockExpect(address(projects), _ownerOfCall, abi.encode(_ownerData));

        // mock first permissions call
        bytes memory _permissionsCall = abi.encodeCall(
            IJBPermissions.hasPermission,
            (address(this), address(1), 1, JBPermissionIds.SET_PRIMARY_TERMINAL, true, true)
        );
        bytes memory _permissionsReturned = abi.encode(false);

        mockExpect(address(permissions), _permissionsCall, _permissionsReturned);

        vm.expectRevert(
            abi.encodeWithSelector(
                JBPermissioned.JBPermissioned_Unauthorized.selector, _ownerData, address(this), 1, 15
            )
        );
        _directory.setPrimaryTerminalOf(1, _token, _terminalToAdd);
    }

    function test_GivenNoValidAccountingContextForTokenOf() external whenCallerHasPermission {
        // it should revert with TOKEN_NOT_ACCEPTED
        // accounting context
        JBAccountingContext memory _context = JBAccountingContext({token: address(0), decimals: 6, currency: uint32(1)});

        // mock accountingContext call
        bytes memory _contextCall = abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (1, _token));
        bytes memory _contextReturn = abi.encode(_context);

        mockExpect(address(_terminalToAdd), _contextCall, _contextReturn);

        vm.expectRevert(
            abi.encodeWithSelector(JBDirectory.JBDirectory_TokenNotAccepted.selector, 1, _token, _terminalToAdd)
        );
        _directory.setPrimaryTerminalOf(1, _token, _terminalToAdd);
    }

    function test_RevertIf_GivenTerminalHasAlreadyBeenAdded()
        external
        whenCallerHasPermission
        givenValidAccountingContext
    {
        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(
            _mockController
        );
        // mock erc165 call
        bytes memory _supportCall =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId));
        bytes memory _supportReturned = abi.encode(false);

        mockExpect(address(_mockController), _supportCall, _supportReturned);

        // it should not add the terminal, but set it as primary
        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminalToAdd;

        vm.expectEmit();
        emit IJBDirectory.SetTerminals(1, _terminals, address(this));

        _directory.setTerminalsOf(1, _terminals);

        // prove that the terminal was not added - forces this test to fail as intended
        vm.expectEmit();
        emit IJBDirectory.SetPrimaryTerminal(1, _token, _terminals[0], address(this));

        // set the primary next and mock whatever calls
        _directory.setPrimaryTerminalOf(1, _token, _terminals[0]);
    }

    function test_GivenProjectIsNotAllowedToSetTerminals()
        external
        whenCallerHasPermission
        givenValidAccountingContext
    {
        // it should revert with SET_TERMINALS_NOT_ALLOWED

        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(
            _mockController
        );

        // mock erc165 call
        bytes memory _supportCall =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId));
        bytes memory _supportReturned = abi.encode(true);

        mockExpect(address(_mockController), _supportCall, _supportReturned);

        // mock setTerminalsAllowed call
        bytes memory _allowedCall = abi.encodeCall(IJBDirectoryAccessControl.setTerminalsAllowed, (1));
        bytes memory _allowedReturn = abi.encode(false);

        mockExpect(address(_mockController), _allowedCall, _allowedReturn);

        vm.expectRevert(JBDirectory.JBDirectory_SetTerminalsNotAllowed.selector);
        _directory.setPrimaryTerminalOf(1, _token, _terminalToAdd);
    }

    function test_GivenProjectIsAllowedToSetTerminals()
        external
        whenCallerHasPermission
        givenValidAccountingContext
        givenTerminalHasNotBeenAdded
    {
        // it should set the terminal and emit AddTerminal
        // it should set the terminal as primary and emit SetPrimaryTerminal

        stdstore.target(address(_directory)).sig("controllerOf(uint256)").with_key(1).depth(0).checked_write(
            _mockController
        );
        // mock erc165 call
        bytes memory _supportCall =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId));
        bytes memory _supportReturned = abi.encode(false);

        mockExpect(address(_mockController), _supportCall, _supportReturned);

        _directory.setPrimaryTerminalOf(1, _token, _terminalToAdd);
    }
}
