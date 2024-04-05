// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBDirectorySetup} from "./JBDirectorySetup.sol";

contract TestPrimaryTerminalOf_Local is JBDirectorySetup {
    uint256 _projectId = 1;
    address _mockTerminal = makeAddr("mockTerminal");
    address _mockTerminal2 = makeAddr("mockTerminal2");
    address _mockToken = makeAddr("mockToken");

    function setUp() public {
        super.directorySetup();
    }

    function test_WhenThereAreNoTerminalsSupportingTheInputToken() external {
        // it will return the zero address
    }

    modifier whenThereIsAPrimaryTerminal() {
        _;
    }

    function test_GivenThereIsAPrimaryTerminalForTheToken() external whenThereIsAPrimaryTerminal {
        // it will return the primary terminal

        // first set the primary terminal

        // mock call to JBProjects ownerOf which will give permission
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to the terminal accountingContextForTokenOf

        // accounting context needed for call
        JBAccountingContext memory _context =
            JBAccountingContext({token: _mockToken, decimals: 18, currency: uint32(1)});
        mockExpect(
            address(_mockTerminal),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, _mockToken)),
            abi.encode(_context)
        );

        // mock call to "controller" (zero address here) for interface supp
        mockExpect(
            address(0),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId)),
            abi.encode(true)
        );

        // mock call to "controller" (zero address here) for setTerminalsAllowed
        mockExpect(
            address(0), abi.encodeCall(IJBDirectoryAccessControl.setTerminalsAllowed, (_projectId)), abi.encode(true)
        );

        // Set the primary terminal of using the previous mocks
        _directory.setPrimaryTerminalOf(_projectId, _mockToken, IJBTerminal(_mockTerminal));

        // Make sure it is stored correctly
        IJBTerminal _storedTerminal = _directory.primaryTerminalOf(_projectId, _mockToken);
        assertEq(address(_storedTerminal), _mockTerminal);
    }

    function test_GivenThereAreMultipleTerminalsWithProperAccountingContextForTokenOf() external {
        // it will check each terminals accountingContextForTokenOf and return the first
    }

    function test_GivenThereAreMultipleTerminalsButNoneWithTheProperAccountingContextForTokenOf() external {
        // it will return the zero address

        // first set the terminals

        // mock call to JBProjects ownerOf which will give permission
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to the terminal accountingContextForTokenOf

        // accounting context needed for call
        JBAccountingContext memory _context = JBAccountingContext({token: address(0), decimals: 0, currency: uint32(0)});
        mockExpect(
            address(_mockTerminal),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, address(0))),
            abi.encode(_context)
        );

        // mock call the the 2nd terminal accountingContextForTokenOf

        // accounting context needed for call
        mockExpect(
            address(_mockTerminal2),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, address(0))),
            abi.encode(_context)
        );

        // mock call to "controller" (zero address here) for interface supp
        mockExpect(
            address(0),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBDirectoryAccessControl).interfaceId)),
            abi.encode(true)
        );

        // mock call to "controller" (zero address here) for setTerminalsAllowed
        mockExpect(
            address(0), abi.encodeCall(IJBDirectoryAccessControl.setTerminalsAllowed, (_projectId)), abi.encode(true)
        );

        // terminals to set
        IJBTerminal[] memory _terminals = new IJBTerminal[](2);
        _terminals[0] = IJBTerminal(_mockTerminal);
        _terminals[1] = IJBTerminal(_mockTerminal2);

        // Set the primary terminal of using the previous mocks
        _directory.setTerminalsOf(_projectId, _terminals);

        IJBTerminal returnedTerminal = _directory.primaryTerminalOf(_projectId, address(0));
        assertEq(address(returnedTerminal), address(0));
    }
}
