// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestRedeemTokensOf_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    uint256 _maxRedemptionRate = JBConstants.MAX_REDEMPTION_RATE;
    uint256 _halfRedemptionRate = JBConstants.MAX_REDEMPTION_RATE / 2;

    address _holder = makeAddr("holder");
    address payable _bene = payable(makeAddr("beneficiary"));
    address _mockToken = makeAddr("mockToken");
    IJBRedeemHook _mockHook = IJBRedeemHook(makeAddr("redeemHook"));

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
                (address(_bene), address(_holder), _projectId, JBPermissionIds.REDEEM_TOKENS, true, true)
            ),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSignature("UNAUTHORIZED()"));
        vm.prank(_bene);
        _terminal.redeemTokensOf(_holder, _projectId, _mockToken, _defaultAmount, _minReclaimed, _bene, "");
    }

    modifier whenCallerHasPermission() {
        vm.prank(_bene);

        // mock call to JBPermissions hasPermission
        mockExpect(
            address(permissions),
            abi.encodeCall(
                IJBPermissions.hasPermission,
                (address(_bene), address(_holder), _projectId, JBPermissionIds.REDEEM_TOKENS, true, true)
            ),
            abi.encode(true)
        );

        _;
    }

    function test_GivenRedeemCountLTMinTokensReclaimed() external whenCallerHasPermission {
        // it will revert INADEQUATE_RECLAIM_AMOUNT

        uint256 reclaimAmount = 1e9;
        JBRedeemHookSpecification[] memory hookSpecifications = new JBRedeemHookSpecification[](0);
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordRedemptionFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordRedemptionFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxRedemptionRate, hookSpecifications)
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

        _terminal.redeemTokensOf(_holder, _projectId, _mockToken, _defaultAmount, _minReclaimed, _bene, "");
    }

    function test_GivenRedeemCountGtZero() external whenCallerHasPermission {
        // it will call directory controller of and burnTokensOf

        uint256 reclaimAmount = 1e9;
        JBRedeemHookSpecification[] memory hookSpecifications = new JBRedeemHookSpecification[](0);
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordRedemptionFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordRedemptionFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxRedemptionRate, hookSpecifications)
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
        vm.expectRevert(abi.encodeWithSignature("INADEQUATE_RECLAIM_AMOUNT()"));
        _terminal.redeemTokensOf(_holder, _projectId, _mockToken, _defaultAmount, 1e18, _bene, ""); // minReclaimAmount
            // = 1e18 but only 1e19 reclaimed
    }

    function test_GivenReclaimAmountGtZeroBeneficiaryIsNotFeelessAndRedemptionRateDneqMAX_REDEMPTION_RATE()
        external
        whenCallerHasPermission
    {
        // it will subtract the fee for the reclaim

        uint256 reclaimAmount = 1e9;
        JBRedeemHookSpecification[] memory hookSpecifications = new JBRedeemHookSpecification[](0);
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordRedemptionFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordRedemptionFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _halfRedemptionRate, hookSpecifications)
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
        uint256 tax = JBFees.feeAmountIn(reclaimAmount, 25); // 25 = default fee)
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
            abi.encodeCall(IJBFeeTerminal.executeProcessFee, (_projectId, _mockToken, tax, _bene, _terminal)),
            ""
        );

        _terminal.redeemTokensOf(_holder, _projectId, _mockToken, _defaultAmount, _minReclaimed, _bene, "");
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

    /* function test_GivenDataHookReturnsRedeemHookSpecsHookIsFeelessAndTokenIsNative()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will pass the full amount to the hook and emit HookAfterRecordRedeem

        
    } */

    function test_GivenDataHookReturnsRedeemHookSpecsHookIsFeelessAndTokenIsErc20()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will safeIncreaseAllowance pass the full amount to the hook and emit HookAfterRecordRedeem

        // mint mocked erc20 tokens to hodler
        _mockToken2.mint(address(_terminal), _defaultAmount * 10);
        _mockToken2.mint(address(_holder), _defaultAmount * 10);

        // approve those tokens to the terminal
        vm.prank(_holder);
        _mockToken2.approve(address(_terminal), _defaultAmount);

        vm.prank(address(_terminal));
        _mockToken2.approve(address(_mockHook), _defaultAmount);

        uint256 reclaimAmount = 1e9;
        JBRedeemHookSpecification[] memory hookSpecifications = new JBRedeemHookSpecification[](1);
        hookSpecifications[0] = JBRedeemHookSpecification({hook: _mockHook, amount: _defaultAmount, metadata: ""});
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordRedemptionFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordRedemptionFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxRedemptionRate, hookSpecifications)
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

        JBTokenAmount memory reclaimedAmount = JBTokenAmount(address(_mockToken2), reclaimAmount, 0, 0);
        JBTokenAmount memory forwardedAmount = JBTokenAmount(address(_mockToken2), _defaultAmount, 0, 0);

        // needed for hook call
        JBAfterRedeemRecordedContext memory context = JBAfterRedeemRecordedContext({
            holder: _holder,
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            redeemCount: _defaultAmount,
            reclaimedAmount: reclaimedAmount,
            forwardedAmount: forwardedAmount,
            redemptionRate: _maxRedemptionRate,
            beneficiary: _bene,
            hookMetadata: "",
            redeemerMetadata: ""
        });

        mockExpect(address(_mockHook), abi.encodeCall(IJBRedeemHook.afterRedeemRecordedWith, (context)), "");

        // ensure approval is increased
        vm.expectCall(address(_mockToken2), abi.encodeCall(IERC20.approve, (address(_mockHook), _defaultAmount * 2)));

        vm.expectEmit();
        emit IJBRedeemTerminal.HookAfterRecordRedeem(_mockHook, context, _defaultAmount, 0, address(_bene));

        vm.prank(_bene);
        _terminal.redeemTokensOf(_holder, _projectId, address(_mockToken2), _defaultAmount, _minReclaimed, _bene, "");
    }

    /* function test_GivenDataHookReturnsRedeemHookSpecsHookIsNotFeelessAndTokenIsNative()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will calculate the fee pass the amount to the hook and emit HookAfterRecordRedeem
    } */

    function test_GivenDataHookReturnsRedeemHookSpecsHookIsNotFeelessAndTokenIsErc20()
        external
        whenADataHookIsConfigured
        whenCallerHasPermission
    {
        // it will safeIncreaseAllowance pass the amount to the hook and emit HookAfterRecordRedeem

        // mint mocked erc20 tokens to hodler
        _mockToken2.mint(address(_terminal), _defaultAmount * 10);
        _mockToken2.mint(address(_holder), _defaultAmount * 10);

        // approve those tokens to the terminal
        vm.prank(_holder);
        _mockToken2.approve(address(_terminal), _defaultAmount);

        vm.prank(address(_terminal));
        _mockToken2.approve(address(_mockHook), _defaultAmount);

        uint256 reclaimAmount = 1e9;
        JBRedeemHookSpecification[] memory hookSpecifications = new JBRedeemHookSpecification[](1);
        JBRedeemHookSpecification[] memory paySpecs = new JBRedeemHookSpecification[](0);
        hookSpecifications[0] = JBRedeemHookSpecification({hook: _mockHook, amount: _defaultAmount, metadata: ""});
        JBAccountingContext[] memory mockBalanceContext = new JBAccountingContext[](0);
        JBAccountingContext memory mockTokenContext = JBAccountingContext({token: address(0), decimals: 0, currency: 0});
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordRedemptionFor
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordRedemptionFor,
                (_holder, _projectId, _defaultAmount, mockTokenContext, mockBalanceContext, "")
            ),
            abi.encode(returnedRuleset, reclaimAmount, _maxRedemptionRate, hookSpecifications)
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

        uint256 hookTax = JBFees.feeAmountIn(_defaultAmount, 25);
        uint256 passedAfterTax = _defaultAmount - hookTax;

        JBTokenAmount memory reclaimedAmount = JBTokenAmount(address(_mockToken2), reclaimAmount, 0, 0);
        JBTokenAmount memory forwardedAmount = JBTokenAmount(address(_mockToken2), passedAfterTax, 0, 0);
        JBTokenAmount memory feeRepayAmount = JBTokenAmount(address(_mockToken2), hookTax, 0, 0);

        // needed for hook call
        JBAfterRedeemRecordedContext memory context = JBAfterRedeemRecordedContext({
            holder: _holder,
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            redeemCount: _defaultAmount,
            reclaimedAmount: reclaimedAmount,
            forwardedAmount: forwardedAmount,
            redemptionRate: _maxRedemptionRate,
            beneficiary: _bene,
            hookMetadata: "",
            redeemerMetadata: ""
        });

        mockExpect(address(_mockHook), abi.encodeCall(IJBRedeemHook.afterRedeemRecordedWith, (context)), "");

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
                (address(_terminal), feeRepayAmount, _projectId, _bene, bytes(abi.encodePacked(_projectId)))
            ),
            abi.encode(returnedRuleset, 0, paySpecs)
        );

        vm.expectEmit();
        emit IJBRedeemTerminal.HookAfterRecordRedeem(_mockHook, context, passedAfterTax, hookTax, address(_bene));

        vm.prank(_bene);
        _terminal.redeemTokensOf(_holder, _projectId, address(_mockToken2), _defaultAmount, _minReclaimed, _bene, "");
    }
}
