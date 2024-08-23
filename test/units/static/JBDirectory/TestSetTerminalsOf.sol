// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestSetTerminalsOf_Local is JBDirectorySetup {
    using stdStorage for StdStorage;

    IJBTerminal _terminalToAdd = IJBTerminal(makeAddr("newTerminal"));
    address _mockController = makeAddr("controller");
    address _token = makeAddr("newToken");

    function setUp() public {
        super.directorySetup();
    }

    modifier whenCallerHasPermission() {
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(this));

        mockExpect(address(projects), _ownerOfCall, _ownerData);
        _;
    }

    modifier givenSetTerminalsAllowed() {
        // it should revert with revert SET_TERMINALS_NOT_ALLOWED()
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
        bytes memory _allowedReturn = abi.encode(true);

        mockExpect(address(_mockController), _allowedCall, _allowedReturn);
        _;
    }

    function test_GivenNotSetTerminalsAllowed() external whenCallerHasPermission {
        // it should revert with revert SET_TERMINALS_NOT_ALLOWED()
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

        // needed for the call
        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminalToAdd;

        vm.expectRevert(JBDirectory.JBDirectory_SetTerminalsNotAllowed.selector);
        _directory.setTerminalsOf(1, _terminals);
    }

    function test_WhenCallerHasNoPermission() external {
        // it should revert with UNAUTHORIZED()
        // mock ownerOf call
        bytes memory _ownerOfCall = abi.encodeCall(IERC721.ownerOf, (1));
        bytes memory _ownerData = abi.encode(address(1));

        mockExpect(address(projects), _ownerOfCall, _ownerData);

        // mock first permissions call
        bytes memory _permissionsCall = abi.encodeCall(
            IJBPermissions.hasPermission, (address(this), address(1), 1, JBPermissionIds.SET_TERMINALS, true, true)
        );
        bytes memory _permissionsReturned = abi.encode(false);

        mockExpect(address(permissions), _permissionsCall, _permissionsReturned);

        // needed for the call
        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminalToAdd;

        vm.expectRevert(JBPermissioned.JBPermissioned_Unauthorized.selector);
        _directory.setTerminalsOf(1, _terminals);
    }

    function test_GivenDuplicateTerminalsWereAdded() external whenCallerHasPermission givenSetTerminalsAllowed {
        // it should revert with DUPLICATE_TERMINALS()
        // needed for the call
        IJBTerminal[] memory _terminals = new IJBTerminal[](2);
        _terminals[0] = _terminalToAdd;
        _terminals[1] = _terminalToAdd;

        vm.expectRevert(abi.encodeWithSelector(JBDirectory.JBDirectory_DuplicateTerminals.selector, _terminalToAdd));
        _directory.setTerminalsOf(1, _terminals);
    }

    function test_GivenDuplicateTerminalsWereNotAdded() external whenCallerHasPermission givenSetTerminalsAllowed {
        // it should set terminals and emit SetTerminals

        // needed for the call
        IJBTerminal[] memory _terminals = new IJBTerminal[](1);
        _terminals[0] = _terminalToAdd;

        vm.expectEmit();
        emit IJBDirectory.SetTerminals(1, _terminals, address(this));

        _directory.setTerminalsOf(1, _terminals);
    }
}
