// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestCurrentTotalSurplusOf_Local is JBTerminalStoreSetup {
    uint256 _projectId = 1;
    uint256 _decimals = 18;
    uint256 _currency = uint32(uint160(makeAddr("token")));

    // Mocks
    IJBTerminal _terminal1 = IJBTerminal(makeAddr("terminal1"));
    IJBTerminal _terminal2 = IJBTerminal(makeAddr("terminal2"));

    function setUp() public {
        super.terminalStoreSetup();
    }

    function test_WhenTerminalsAreConfiguredInJBDirectory() external {
        // it will return the cumulative surplus

        // return data for mock call
        IJBTerminal[] memory _terminals = new IJBTerminal[](2);
        _terminals[0] = _terminal1;
        _terminals[1] = _terminal2;

        // mock call to JBDirectory terminalsOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.terminalsOf, (_projectId));
        bytes memory _returned = abi.encode(_terminals);
        mockExpect(address(directory), _directoryCall, _returned);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal1Call = abi.encodeCall(
            IJBTerminal.currentSurplusOf, (_projectId, new JBAccountingContext[](0), _decimals, _currency)
        );
        bytes memory _terminal1Return = abi.encode(1e18);
        mockExpect(address(_terminal1), _terminal1Call, _terminal1Return);

        // mock call to first terminal currentSurplusOf
        bytes memory _terminal2Call = abi.encodeCall(
            IJBTerminal.currentSurplusOf, (_projectId, new JBAccountingContext[](0), _decimals, _currency)
        );
        bytes memory _terminal2Return = abi.encode(2e18);
        mockExpect(address(_terminal2), _terminal2Call, _terminal2Return);

        uint256 sum = _store.currentTotalSurplusOf(_projectId, _decimals, _currency);
        assertEq(3e18, sum);
    }

    function test_WhenTerminalsAreNotConfiguredInJBDirectory() external {
        // it will return zero

        // return data for mock call
        IJBTerminal[] memory _terminals = new IJBTerminal[](0);

        // mock call to JBDirectory terminalsOf
        bytes memory _directoryCall = abi.encodeCall(IJBDirectory.terminalsOf, (_projectId));
        bytes memory _returned = abi.encode(_terminals);
        mockExpect(address(directory), _directoryCall, _returned);

        uint256 sum = _store.currentTotalSurplusOf(_projectId, _decimals, _currency);
        assertEq(0, sum);
    }
}
