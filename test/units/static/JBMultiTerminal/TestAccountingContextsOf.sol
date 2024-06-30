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

        // mock call to rulesets currentOf returning 0 to bypass ruleset checking

        // setup: return data
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        // mock supports interface call
        mockExpect(
            _usdc, abi.encodeCall(IERC165.supportsInterface, (type(IERC20Metadata).interfaceId)), abi.encode(true)
        );

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({token: _usdc, decimals: 6, currency: uint32(uint160(_usdc))});

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
