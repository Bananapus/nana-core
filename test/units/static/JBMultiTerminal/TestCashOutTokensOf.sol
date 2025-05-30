// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestCashOutTokensOf_Local is JBMultiTerminalSetup {
    uint64 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    uint16 _maxCashOutTaxRate = JBConstants.MAX_CASH_OUT_TAX_RATE;
    uint16 _halfCashOutTaxRate = JBConstants.MAX_CASH_OUT_TAX_RATE / 2;

    address _holder = makeAddr("holder");
    address payable _bene = payable(makeAddr("beneficiary"));
    address _mockToken = makeAddr("mockToken");
    IJBCashOutHook _mockHook = IJBCashOutHook(makeAddr("cashOutHook"));

    // mock erc20 necessary for balance checks
    MockERC20 _mockToken2;

    uint256 _minReclaimed;

    function setUp() public {
        super.multiTerminalSetup();

        _mockToken2 = new MockERC20("testToken", "TT");
    }

    function test_WhenCallerDNHavePermission() external {
        // it will revert UNAUTHORIZED

        // mock call to JBPermissions hasPermission
        mockExpect(
            address(permissions),
            abi.encodeCall(
                IJBPermissions.hasPermission,
                (address(_bene), address(_holder), _projectId, JBPermissionIds.CASH_OUT_TOKENS, true, true)
            ),
            abi.encode(false)
        );

        vm.expectRevert(
            abi.encodeWithSelector(JBPermissioned.JBPermissioned_Unauthorized.selector, _holder, _bene, _projectId, 3)
        );
        vm.prank(_bene);
        _terminal.cashOutTokensOf(_holder, _projectId, _defaultAmount, _mockToken, _minReclaimed, _bene, "");
    }

    modifier whenCallerHasPermission() {
        vm.prank(_bene);

        // mock call to JBPermissions hasPermission
        mockExpect(
            address(permissions),
            abi.encodeCall(
                IJBPermissions.hasPermission,
                (address(_bene), address(_holder), _projectId, JBPermissionIds.CASH_OUT_TOKENS, true, true)
            ),
            abi.encode(true)
        );

        _;
    }

    function test_GivenCashOutCountLTMinTokensReclaimed() external whenCallerHasPermission {
        // it will revert UNDER_MIN_TOKENS_RECLAIMED

        uint256 reclaimAmount = 1e9;
        JBCashOutHookSpecification[] memory hookSpecifications = new JBCashOutHookSpecification[](0);
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordCashOutFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordCashOutFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxCashOutTaxRate, hookSpecifications)
        );

        // mock call to find the controller (we'll just use this contracts address for simplicity)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock controller burn call
        mockExpect(
            address(this), abi.encodeCall(IJBController.burnTokensOf, (_holder, _projectId, _defaultAmount, "")), ""
        );

        // put code at mockToken address to pass OZ Address check
        vm.etch(_mockToken, abi.encode(1));

        // mock feeless address check
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_bene)), abi.encode(true));

        _terminal.cashOutTokensOf(_holder, _projectId, _defaultAmount, _mockToken, _minReclaimed, _bene, "");
    }

    function test_GivenCashOutCountGtZero() external whenCallerHasPermission {
        // it will call directory controller of and burnTokensOf

        uint256 reclaimAmount = 1e9;
        JBCashOutHookSpecification[] memory hookSpecifications = new JBCashOutHookSpecification[](0);
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordCashOutFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordCashOutFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxCashOutTaxRate, hookSpecifications)
        );

        // mock call to find the controller (we'll just use this contracts address for simplicity)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock controller burn call
        mockExpect(
            address(this), abi.encodeCall(IJBController.burnTokensOf, (_holder, _projectId, _defaultAmount, "")), ""
        );

        // put code at mockToken address to pass OZ Address check
        vm.etch(_mockToken, abi.encode(1));

        // mock feeless address check
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_bene)), abi.encode(true));
        vm.expectRevert(
            abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_UnderMinTokensReclaimed.selector, 1e9, 1e18)
        );
        _terminal.cashOutTokensOf(_holder, _projectId, _defaultAmount, _mockToken, 1e18, _bene, ""); // minReclaimAmount
            // = 1e18 but only 1e9 reclaimed
    }

    function test_GivenReclaimAmountGtZeroBeneficiaryIsNotFeelessAndCashOutRateDneqMAX_CASH_OUT_RATE()
        external
        whenCallerHasPermission
    {
        // it will subtract the fee for the reclaim

        uint256 reclaimAmount = 1e9;
        JBCashOutHookSpecification[] memory hookSpecifications = new JBCashOutHookSpecification[](0);
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordCashOutFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordCashOutFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _halfCashOutTaxRate, hookSpecifications)
        );

        // mock call to find the controller (we'll just use this contracts address for simplicity)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock controller burn call
        mockExpect(
            address(this), abi.encodeCall(IJBController.burnTokensOf, (_holder, _projectId, _defaultAmount, "")), ""
        );

        // put code at mockToken address to pass OZ Address check
        vm.etch(_mockToken, abi.encode(1));

        // mock feeless address check
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_bene)), abi.encode(false));

        // get fee amount
        uint256 tax = JBFees.feeAmountFrom(reclaimAmount, 25); // 25 = default fee)
        uint256 transferredAmount = reclaimAmount - tax;

        // transfer reclaimed to beneficiary
        mockExpect(_mockToken, abi.encodeCall(IERC20.transfer, (_bene, transferredAmount)), abi.encode(true));

        // find the terminal where subtracted fees are sent
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _mockToken)),
            abi.encode(address(_terminal))
        );

        // executeProcessFee
        mockExpect(
            address(_terminal),
            abi.encodeCall(JBMultiTerminal.executeProcessFee, (_projectId, _mockToken, tax, _bene, _terminal)),
            ""
        );

        _terminal.cashOutTokensOf(_holder, _projectId, _defaultAmount, _mockToken, _minReclaimed, _bene, "");
    }

    // covered above / in other units that test transfers
    /* function test_GivenTheTokenIsNative() external whenCallerHasPermission {
        // it will sendValue
    }

    function test_GivenTheTokenIsErc20() external whenCallerHasPermission {
        // it will safeTransfer tokens
    }

    function test_GivenAmountEligibleForFeesDneqZero() external whenCallerHasPermission {
        // it will call directory primaryTerminalOf and process the fee
    } */

    modifier whenADataHookIsConfigured() {
        _;
    }

    /* function test_GivenDataHookReturnsCashOutHookSpecsHookIsFeelessAndTokenIsNative()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will pass the full amount to the hook and emit HookAfterRecordCashOut

        
    } */

    function test_GivenDataHookReturnsCashOutHookSpecsHookIsFeelessAndTokenIsErc20()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will safeIncreaseAllowance pass the full amount to the hook and emit HookAfterRecordCashOut

        // mint mocked erc20 tokens to hodler
        _mockToken2.mint(address(_terminal), _defaultAmount * 10);
        _mockToken2.mint(address(_holder), _defaultAmount * 10);

        // approve those tokens to the terminal
        vm.prank(_holder);
        _mockToken2.approve(address(_terminal), _defaultAmount);

        vm.prank(address(_terminal));
        _mockToken2.approve(address(_mockHook), _defaultAmount);

        uint256 reclaimAmount = 1e9;
        JBCashOutHookSpecification[] memory hookSpecifications = new JBCashOutHookSpecification[](1);
        hookSpecifications[0] = JBCashOutHookSpecification({hook: _mockHook, amount: _defaultAmount, metadata: ""});
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordCashOutFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordCashOutFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxCashOutTaxRate, hookSpecifications)
        );

        // mock call to find the controller (we'll just use this contracts address for simplicity)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock controller burn call
        mockExpect(
            address(this), abi.encodeCall(IJBController.burnTokensOf, (_holder, _projectId, _defaultAmount, "")), ""
        );

        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_bene)), abi.encode(true));

        mockExpect(
            address(feelessAddresses),
            abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(_mockHook))),
            abi.encode(true)
        );

        JBTokenAmount memory reclaimedAmount = JBTokenAmount(address(_mockToken2), 0, 0, reclaimAmount);
        JBTokenAmount memory forwardedAmount = JBTokenAmount(address(_mockToken2), 0, 0, _defaultAmount);

        // needed for hook call
        JBAfterCashOutRecordedContext memory context = JBAfterCashOutRecordedContext({
            holder: _holder,
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            cashOutCount: _defaultAmount,
            reclaimedAmount: reclaimedAmount,
            forwardedAmount: forwardedAmount,
            cashOutTaxRate: _maxCashOutTaxRate,
            beneficiary: _bene,
            hookMetadata: "",
            cashOutMetadata: ""
        });

        mockExpect(address(_mockHook), abi.encodeCall(IJBCashOutHook.afterCashOutRecordedWith, (context)), "");

        // ensure approval is increased
        vm.expectCall(address(_mockToken2), abi.encodeCall(IERC20.approve, (address(_mockHook), _defaultAmount * 2)));

        vm.expectEmit();
        emit IJBCashOutTerminal.HookAfterRecordCashOut(_mockHook, context, _defaultAmount, 0, address(_bene));

        vm.prank(_bene);
        _terminal.cashOutTokensOf(_holder, _projectId, _defaultAmount, address(_mockToken2), _minReclaimed, _bene, "");
    }

    /* function test_GivenDataHookReturnsCashOutHookSpecsHookIsNotFeelessAndTokenIsNative()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will calculate the fee pass the amount to the hook and emit HookAfterRecordCashOut
    } */

    function test_GivenDataHookReturnsCashOutHookSpecsHookIsNotFeelessAndTokenIsErc20()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will safeIncreaseAllowance pass the amount to the hook and emit HookAfterRecordCashOut

        // mint mocked erc20 tokens to hodler
        _mockToken2.mint(address(_terminal), _defaultAmount * 10);
        _mockToken2.mint(address(_holder), _defaultAmount * 10);

        // approve those tokens to the terminal
        vm.prank(_holder);
        _mockToken2.approve(address(_terminal), _defaultAmount);

        vm.prank(address(_terminal));
        _mockToken2.approve(address(_mockHook), _defaultAmount);

        uint256 reclaimAmount = 1e9;
        JBCashOutHookSpecification[] memory hookSpecifications = new JBCashOutHookSpecification[](1);
        JBCashOutHookSpecification[] memory paySpecs = new JBCashOutHookSpecification[](0);
        hookSpecifications[0] = JBCashOutHookSpecification({hook: _mockHook, amount: _defaultAmount, metadata: ""});
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            weightCutPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordCashOutFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordCashOutFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxCashOutTaxRate, hookSpecifications)
        );

        // mock call to find the controller (we'll just use this contracts address for simplicity)
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock controller burn call
        mockExpect(
            address(this), abi.encodeCall(IJBController.burnTokensOf, (_holder, _projectId, _defaultAmount, "")), ""
        );

        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_bene)), abi.encode(true));

        mockExpect(
            address(feelessAddresses),
            abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(_mockHook))),
            abi.encode(false)
        );

        uint256 hookTax = JBFees.feeAmountFrom(_defaultAmount, 25);
        uint256 passedAfterTax = _defaultAmount - hookTax;

        JBTokenAmount memory reclaimedAmount = JBTokenAmount(address(_mockToken2), 0, 0, reclaimAmount);
        JBTokenAmount memory forwardedAmount = JBTokenAmount(address(_mockToken2), 0, 0, passedAfterTax);
        JBTokenAmount memory feeRepayAmount = JBTokenAmount(address(_mockToken2), 0, 0, hookTax);

        // needed for hook call
        JBAfterCashOutRecordedContext memory context = JBAfterCashOutRecordedContext({
            holder: _holder,
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            cashOutCount: _defaultAmount,
            reclaimedAmount: reclaimedAmount,
            forwardedAmount: forwardedAmount,
            cashOutTaxRate: _maxCashOutTaxRate,
            beneficiary: _bene,
            hookMetadata: "",
            cashOutMetadata: ""
        });

        mockExpect(address(_mockHook), abi.encodeCall(IJBCashOutHook.afterCashOutRecordedWith, (context)), "");

        // primary terminal check
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, address(_mockToken2))),
            abi.encode(address(_terminal))
        );

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom,
                (address(_terminal), feeRepayAmount, _projectId, _bene, bytes(abi.encodePacked(uint256(_projectId))))
            ),
            abi.encode(returnedRuleset, 0, paySpecs)
        );
        vm.expectEmit();
        emit IJBCashOutTerminal.HookAfterRecordCashOut(_mockHook, context, passedAfterTax, hookTax, address(_bene));

        vm.prank(_bene);
        _terminal.cashOutTokensOf(_holder, _projectId, _defaultAmount, address(_mockToken2), _minReclaimed, _bene, "");
    }
}
