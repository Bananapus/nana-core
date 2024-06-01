// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestMigrateBalanceOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    address _bene = makeAddr("beneficiary");
    address _native = JBConstants.NATIVE_TOKEN;
    uint256 _nativeCurrency = uint32(uint160(_native));
    address _usdc = makeAddr("USDC");
    uint256 _usdcCurrency = uint32(uint160(_usdc));

    IJBTerminal _newTerminal = IJBTerminal(makeAddr("newTerminal"));

    function setUp() public {
        super.multiTerminalSetup();
    }

    modifier whenPermissioned() {
        // mock call to JBProjects ownerOf
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(0)));

        // mock call to JBPermissions hasPermission
        mockExpect(
            address(permissions),
            abi.encodeCall(
                IJBPermissions.hasPermission,
                (address(this), address(0), _projectId, JBPermissionIds.MIGRATE_TERMINAL, true, true)
            ),
            abi.encode(true)
        );

        _;
    }

    function test_WhenCallerDoesNotHavePermission() external {
        // it will revert UNAUTHORIZED

        // mock call to JBProjects ownerOf
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(0)));

        // mock call to JBPermissions hasPermission
        mockExpect(
            address(permissions),
            abi.encodeCall(
                IJBPermissions.hasPermission,
                (address(this), address(0), _projectId, JBPermissionIds.MIGRATE_TERMINAL, true, true)
            ),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        _terminal.migrateBalanceOf({projectId: _projectId, token: _native, to: _newTerminal});
    }

    function test_WhenTheTerminalToDoesNotAcceptTheToken() external whenPermissioned {
        // it will revert TERMINAL_TOKENS_INCOMPATIBLE

        // for next mock
        JBAccountingContext memory _context =
            JBAccountingContext({token: _usdc, decimals: 0, currency: uint32(_usdcCurrency)});

        // mock call to the destination terminals accountingContextFor
        mockExpect(
            address(_newTerminal),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, _native)),
            abi.encode(_context)
        );

        vm.expectRevert(abi.encodeWithSignature("TERMINAL_TOKENS_INCOMPATIBLE()"));
        _terminal.migrateBalanceOf({projectId: _projectId, token: _native, to: _newTerminal});
    }

    // held fees have already been unit tested
    /* function test_GivenThereAreHeldFees() external whenBalanceGTZeroAndCallerIsPermissioned {
        // it will process held fees
    } */

    function test_GivenTokenIsERC20() external whenPermissioned {
        // it will safeIncreaseAllowance and addToBalanceOf

        // for next mock
        JBAccountingContext memory _context =
            JBAccountingContext({token: _usdc, decimals: 6, currency: uint32(_usdcCurrency)});

        // mock call to the destination terminals accountingContextFor
        mockExpect(
            address(_newTerminal),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, _usdc)),
            abi.encode(_context)
        );

        // mock call to JBDirectory primaryTerminal
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _usdc)),
            abi.encode(_terminal)
        );

        // mock call to JBTerminalStore
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordTerminalMigration, (_projectId, _usdc)),
            abi.encode(_defaultAmount)
        );

        // mock call for SafeERC20s allowance check
        mockExpect(_usdc, abi.encodeCall(IERC20.allowance, (address(_terminal), address(_newTerminal))), abi.encode(0));

        // mock call for SafeERC20s safeIncreaseAllowance approval
        mockExpect(_usdc, abi.encodeCall(IERC20.approve, (address(_newTerminal), _defaultAmount)), "");

        // mock call to new terminal addToBalance
        mockExpect(
            address(_newTerminal),
            abi.encodeCall(IJBTerminal.addToBalanceOf, (_projectId, _usdc, _defaultAmount, false, "", "")),
            ""
        );

        _terminal.migrateBalanceOf({projectId: _projectId, token: _usdc, to: _newTerminal});
    }

    function test_GivenTokenIsNative() external whenPermissioned {
        // it will addToBalanceOf with value in msgvalue

        // for next mock
        JBAccountingContext memory _context =
            JBAccountingContext({token: _native, decimals: 18, currency: uint32(_nativeCurrency)});

        // mock call to the destination terminals accountingContextFor
        mockExpect(
            address(_newTerminal),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, _native)),
            abi.encode(_context)
        );

        // mock call to JBDirectory primaryTerminal
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _native)),
            abi.encode(_terminal)
        );

        // mock call to JBTerminalStore
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordTerminalMigration, (_projectId, _native)),
            abi.encode(_defaultAmount)
        );

        // mock call to new terminal addToBalance
        mockExpect(
            address(_newTerminal),
            abi.encodeCall(IJBTerminal.addToBalanceOf, (_projectId, _native, _defaultAmount, false, "", "")),
            ""
        );

        vm.expectEmit();
        emit IJBTerminal.MigrateTerminal(_projectId, _native, _newTerminal, _defaultAmount, address(this));

        _terminal.migrateBalanceOf({projectId: _projectId, token: _native, to: _newTerminal});
    }

    function test_WhenBalanceIsZero() external whenPermissioned {
        // it will not add to balance

        // for next mock
        JBAccountingContext memory _context =
            JBAccountingContext({token: _native, decimals: 18, currency: uint32(_nativeCurrency)});

        // mock call to the destination terminals accountingContextFor
        mockExpect(
            address(_newTerminal),
            abi.encodeCall(IJBTerminal.accountingContextForTokenOf, (_projectId, _native)),
            abi.encode(_context)
        );

        // mock call to JBDirectory primaryTerminal
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _native)),
            abi.encode(_terminal)
        );

        // mock call to JBTerminalStore
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordTerminalMigration, (_projectId, _native)),
            abi.encode(0)
        );

        vm.expectEmit();
        emit IJBTerminal.MigrateTerminal(_projectId, _native, _newTerminal, 0, address(this));

        _terminal.migrateBalanceOf({projectId: _projectId, token: _native, to: _newTerminal});
    }
}
