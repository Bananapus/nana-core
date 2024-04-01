// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAccountingContextsFor_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    address _usdc = makeAddr("USDC");
    uint256 _usdcCurrency = uint32(uint160(_usdc));

    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenAccountingContextsAreSet() external {
        // it will return contexts

        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock call to tokens decimals()
        mockExpect(_usdc, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(6));

        // call params
        address[] memory _tokens = new address[](1);
        _tokens[0] = _usdc;

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        JBAccountingContext[] memory _storedContexts = _terminal.accountingContextsOf(_projectId);
        assertEq(_storedContexts[0].currency, _usdcCurrency);
        assertEq(_storedContexts[0].token, _usdc);
        assertEq(_storedContexts[0].decimals, 6);
    }

    function test_WhenAccountingContextsAreNotSet() external {
        // it will return an empty array
        JBAccountingContext[] memory _storedContexts = _terminal.accountingContextsOf(_projectId);
        assertEq(_storedContexts.length, 0);
    }
}
