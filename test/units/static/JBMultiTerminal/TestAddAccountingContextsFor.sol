// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAddAccountingContextsFor_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    address _usdc = makeAddr("USDC");
    uint256 _usdcCurrency = uint32(uint160(_usdc));

    function setUp() public {
        super.multiTerminalSetup();
    }

    function test_WhenCallerIsNotPermissioned() external {
        // it will revert UNAUTHORIZED
    }

    modifier whenCallerIsPermissioned() {
        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(this));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        _;
    }

    function test_GivenTheContextIsAlreadySet() external whenCallerIsPermissioned {
        // it will revert ACCOUNTING_CONTEXT_ALREADY_SET

        // Accounting Context to set
        JBAccountingContext memory _context =
            JBAccountingContext({token: _usdc, decimals: 18, currency: uint32(_usdcCurrency)});

        // Find the storage slot
        bytes32 contextSlot = keccak256(abi.encode(_projectId, uint256(0)));
        bytes32 slot = keccak256(abi.encode(_usdc, contextSlot));

        // Set storage
        vm.store(address(_terminal), slot, bytes32(abi.encode(_context)));

        // setup: return data
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        JBAccountingContext memory _storedContext = _terminal.accountingContextForTokenOf(_projectId, _usdc);
        assertEq(_storedContext.token, _usdc);

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({token: _usdc, decimals: 6, currency: uint32(uint160(_usdc))});

        vm.expectRevert(
            abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_AccountingContextAlreadySet.selector, _usdc)
        );
        _terminal.addAccountingContextsFor(_projectId, _tokens);
    }

    function test_GivenHappyPathERC20() external whenCallerIsPermissioned {
        // it will set the context and emit SetAccountingContext

        // mock call to tokens decimals()
        mockExpect(_usdc, abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(6));

        // setup: return data
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to rulesets currentOf returning 0 to bypass ruleset checking
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({token: _usdc, decimals: 6, currency: uint32(uint160(_usdc))});

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        JBAccountingContext memory _storedContext = _terminal.accountingContextForTokenOf(_projectId, _usdc);
        assertEq(_storedContext.token, _usdc);
        assertEq(_storedContext.decimals, 6);
        assertEq(_storedContext.currency, uint32(uint160(_usdc)));
    }

    function test_GivenHappyPathNative() external whenCallerIsPermissioned {
        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        // mock call to rulesets currentOf returning 0 to bypass ruleset checking

        // setup: return data
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        JBAccountingContext memory _storedContext =
            _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN);
        assertEq(_storedContext.token, JBConstants.NATIVE_TOKEN);
        assertEq(_storedContext.decimals, 18);
        assertEq(_storedContext.currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
    }

    function test_WhenCallerIsController() external {
        // it will alsoGrantAccess

        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(0));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        // setup: return data
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        JBAccountingContext memory _storedContext =
            _terminal.accountingContextForTokenOf(_projectId, JBConstants.NATIVE_TOKEN);
        assertEq(_storedContext.token, JBConstants.NATIVE_TOKEN);
        assertEq(_storedContext.decimals, 18);
        assertEq(_storedContext.currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
    }

    function test_WhenCallerIsControllerAndRulesetDoesntAllow() external {
        // it will revert

        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(0));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        // setup: return data
        JBRuleset memory ruleset = generateUnfriendlyRuleset();

        // mock rulesets call
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_AddingAccountingContextNotAllowed.selector);
        _terminal.addAccountingContextsFor(_projectId, _tokens);
    }

    function test_WhenCurrencyIsNativeButDecimalsDNEQ18() external {
        // it will revert JBMultiTerminal_ZeroAccountingContextDecimals

        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(0));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 17, //invalid
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        // setup: return data
        JBRuleset memory ruleset = generateFriendlyRuleset();

        // mock rulesets call
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_ZeroAccountingContextDecimals.selector);
        _terminal.addAccountingContextsFor(_projectId, _tokens);
    }

    function test_WhenTokenDecimalsDoesNotMatchAccountingContext() external {
        // it will revert JBMultiTerminal_ZeroAccountingContextDecimals

        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(0));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        address someToken = makeAddr("someToken");

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: someToken,
            decimals: 17, // invalid- we will mock a return of 18 decimals
            currency: uint32(uint160(someToken))
        });

        // setup: return data
        JBRuleset memory ruleset = generateFriendlyRuleset();

        // mock rulesets call
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        // mock token call
        mockExpect(address(someToken), abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(18));

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_ZeroAccountingContextDecimals.selector);
        _terminal.addAccountingContextsFor(_projectId, _tokens);
    }

    function test_WhenCurrencyEQZero() external {
        // it will revert JBMultiTerminal_ZeroAccountingContextCurrency

        // mock call to JBProjects ownerOf(_projectId)
        bytes memory _projectsCall = abi.encodeCall(IERC721.ownerOf, (_projectId));
        bytes memory _projectsCallReturn = abi.encode(address(0));
        mockExpect(address(projects), _projectsCall, _projectsCallReturn);

        // mock call to JBDirectory controllerOf(_projectId)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        address someToken = makeAddr("someToken");

        // call params
        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({token: someToken, decimals: 18, currency: uint32(uint160(0))});

        // setup: return data
        JBRuleset memory ruleset = generateFriendlyRuleset();

        // mock rulesets call
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        // mock token call
        mockExpect(address(someToken), abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(18));

        vm.expectRevert(JBMultiTerminal.JBMultiTerminal_ZeroAccountingContextCurrency.selector);
        _terminal.addAccountingContextsFor(_projectId, _tokens);
    }
}
