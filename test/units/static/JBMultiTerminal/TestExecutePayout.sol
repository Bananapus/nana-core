// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestExecutePayout_Local is JBMultiTerminalSetup {
    uint56 _projectId = 1;
    uint56 _noProject = 0;
    uint48 _lockedUntil = 0;
    uint256 _defaultAmount = 1e18;
    uint256 _fee = 25;
    address _hook = makeAddr("splithook");
    address payable _bene = payable(makeAddr("beneficiary"));
    address payable _noBene = payable(address(0));
    address _mockSecondTerminal = makeAddr("anothaOne");

    address _native = JBConstants.NATIVE_TOKEN;
    address _usdc = makeAddr("USDC");

    JBSplit private _split;
    JBSplit private _emptySplit;

    function setUp() public {
        super.multiTerminalSetup();
    }

    modifier whenASplitHookIsConfigured() {
        _split = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(_hook)
        });
        vm.deal(address(_terminal), _defaultAmount);
        vm.startPrank(address(_terminal));

        _;
    }

    function test_GivenTheSplitHookEQFeeless() external whenASplitHookIsConfigured {
        // it will not process a fee

        // mock call to split hook supportsInterface
        mockExpect(
            address(_hook),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBSplitHook).interfaceId)),
            abi.encode(true)
        );

        // mock call to FeelessAddresses isFeeless
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_hook)), abi.encode(true));

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(_hook)
        });

        // Create the context to send to the split hook.
        JBSplitHookContext memory context = JBSplitHookContext({
            token: _native,
            amount: _defaultAmount, // It will call with full amount as netPayoutAmount
            decimals: 0,
            projectId: _noProject,
            groupId: uint256(uint160(_native)),
            split: _splitMemory
        });

        // mock call to hooks processSplitWith
        mockExpect(address(_hook), abi.encodeCall(IJBSplitHook.processSplitWith, (context)), "");

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _split,
            projectId: _noProject,
            token: _native,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenTheSplitHookDNEQFeeless() external whenASplitHookIsConfigured {
        // it will process a fee

        // mock call to split hook supportsInterface
        mockExpect(
            address(_hook),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBSplitHook).interfaceId)),
            abi.encode(true)
        );

        // mock call to FeelessAddresses isFeeless
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_hook)), abi.encode(false));

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(_hook)
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);

        // Create the context to send to the split hook.
        JBSplitHookContext memory context = JBSplitHookContext({
            token: _native,
            amount: _defaultAmount - taxedAmount, // It will call with taxed amount
            decimals: 0,
            projectId: _noProject,
            groupId: uint256(uint160(_native)),
            split: _splitMemory
        });

        // mock call to hooks processSplitWith
        mockExpect(address(_hook), abi.encodeCall(IJBSplitHook.processSplitWith, (context)), "");

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _split,
            projectId: _noProject,
            token: _native,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenTheSplitHookDNSupportSplitHookInterface() external whenASplitHookIsConfigured {
        // it will revert 400_1

        // mock call to split hook supportsInterface
        mockExpect(
            address(_hook),
            abi.encodeCall(IERC165.supportsInterface, (type(IJBSplitHook).interfaceId)),
            abi.encode(false)
        );

        vm.expectRevert(abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_SplitHookInvalid.selector, _hook));
        JBMultiTerminal(address(_terminal)).executePayout({
            split: _split,
            projectId: _noProject,
            token: _native,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenThePayoutTokenIsErc20() external whenASplitHookIsConfigured {
        // it will safe increase allowance

        // mock call to FeelessAddresses isFeeless
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(false)
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);

        // mock call to usdc transfer
        mockExpect(
            address(_usdc),
            abi.encodeCall(IERC20.transfer, (address(this), _defaultAmount - taxedAmount)),
            abi.encode(true)
        );

        // for safe ERC20 check of code length at token address
        vm.etch(_usdc, abi.encode(1));

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _noProject,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenTheProjectsTerminalEQZeroAddress() external {
        // it will revert 404_2

        // mock call to directory primaryTerminalOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _native)),
            abi.encode(IJBTerminal(address(0)))
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                JBMultiTerminal.JBMultiTerminal_RecipientProjectTerminalNotFound.selector, _projectId, _native
            )
        );
        vm.prank(address(_terminal));
        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenPreferAddToBalanceEQTrueAndTerminalEQThisAddress() external {
        // it will call _addToBalanceOf internal

        // mock call to directory primaryTerminalOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _usdc)),
            abi.encode(IJBTerminal(address(_terminal)))
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: true,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        // mock call to JBTerminalStore recordAddedBalanceFor
        mockExpect(
            address(store),
            abi.encodeCall(IJBTerminalStore.recordAddedBalanceFor, (_projectId, _usdc, _defaultAmount)),
            ""
        );

        // for safe ERC20 check of code length at token address
        vm.prank(address(_terminal));

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenPreferAddToBalanceEQTrueAndTerminalEQAnotherAddress() external {
        // it will call that terminals addToBalanceOf

        // mock call to FeelessAddresses isFeeless
        mockExpect(
            address(feelessAddresses),
            abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(_mockSecondTerminal))),
            abi.encode(false)
        );

        // mock call to directory primaryTerminalOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _usdc)),
            abi.encode(IJBTerminal(address(_mockSecondTerminal)))
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: true,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);
        uint256 amountAfterTax = _defaultAmount - taxedAmount;

        // mock call for SafeERC20s allowance check
        mockExpect(
            _usdc, abi.encodeCall(IERC20.allowance, (address(_terminal), address(_mockSecondTerminal))), abi.encode(0)
        );

        // mock call for SafeERC20s safeIncreaseAllowance approval
        mockExpect(_usdc, abi.encodeCall(IERC20.approve, (_mockSecondTerminal, amountAfterTax)), "");

        // mock call to second terminals addToBalanceOf
        mockExpect(
            _mockSecondTerminal,
            abi.encodeCall(
                IJBTerminal.addToBalanceOf,
                (_projectId, _usdc, amountAfterTax, false, "", bytes(abi.encodePacked(uint256(_projectId))))
            ),
            ""
        );

        vm.prank(address(_terminal));
        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenPreferAddToBalanceDNEQTrueAndTerminalEQThisAddress() external {
        // it will call internal _pay

        // mock call to directory primaryTerminalOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _usdc)),
            abi.encode(IJBTerminal(address(_terminal)))
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount = JBTokenAmount(_usdc, 0, 0, _defaultAmount);
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](0);
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

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom,
                (
                    address(_terminal),
                    tokenAmount,
                    _projectId,
                    address(this),
                    bytes(abi.encodePacked(uint256(_projectId)))
                )
            ),
            abi.encode(returnedRuleset, 0, hookSpecifications)
        );

        // for safe ERC20 check of code length at token address
        vm.prank(address(_terminal));

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenPreferAddToBalanceDNEQTrueAndTerminalEQAnotherAddress() external {
        // it will call that terminals pay function

        // mock call to FeelessAddresses isFeeless
        mockExpect(
            address(feelessAddresses),
            abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(_mockSecondTerminal))),
            abi.encode(false)
        );

        // mock call to directory primaryTerminalOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.primaryTerminalOf, (_projectId, _usdc)),
            abi.encode(IJBTerminal(address(_mockSecondTerminal)))
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _projectId,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);
        uint256 amountAfterTax = _defaultAmount - taxedAmount;

        // mock call for SafeERC20s allowance check
        mockExpect(
            _usdc, abi.encodeCall(IERC20.allowance, (address(_terminal), address(_mockSecondTerminal))), abi.encode(0)
        );

        // mock call for SafeERC20s safeIncreaseAllowance approval
        mockExpect(_usdc, abi.encodeCall(IERC20.approve, (_mockSecondTerminal, amountAfterTax)), "");

        // mock call to second terminals pay function
        mockExpect(
            _mockSecondTerminal,
            abi.encodeCall(
                IJBTerminal.pay,
                (_projectId, _usdc, amountAfterTax, address(this), 0, "", bytes(abi.encodePacked(uint256(_projectId))))
            ),
            abi.encode(1e18)
        );

        vm.prank(address(_terminal));
        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenBeneficiaryEQFeeless() external {
        // it will payout to the beneficiary without taking fees

        // mock call to FeelessAddresses isFeeless
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(_bene))), abi.encode(true)
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _bene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        // mock call to usdc transfer
        mockExpect(address(_usdc), abi.encodeCall(IERC20.transfer, (address(_bene), _defaultAmount)), abi.encode(true));

        // for safe ERC20 check of code length at token address
        vm.prank(address(_terminal));

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_GivenBeneficiaryDNEQFeeless() external {
        // it will payout to the beneficiary incurring fee

        // mock call to FeelessAddresses isFeeless
        mockExpect(
            address(feelessAddresses),
            abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(_bene))),
            abi.encode(false)
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _bene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);
        uint256 amountAfterTax = _defaultAmount - taxedAmount;

        // mock call to usdc transfer
        mockExpect(address(_usdc), abi.encodeCall(IERC20.transfer, (address(_bene), amountAfterTax)), abi.encode(true));

        // for safe ERC20 check of code length at token address
        vm.prank(address(_terminal));

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_WhenThereIsNoBeneficiarySplitHookOrProjectToPay() external {
        // it will payout msgSender

        // mock call to FeelessAddresses isFeeless
        mockExpect(
            address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(false)
        );

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);
        uint256 amountAfterTax = _defaultAmount - taxedAmount;

        // mock call to usdc transfer
        mockExpect(address(_usdc), abi.encodeCall(IERC20.transfer, (address(this), amountAfterTax)), abi.encode(true));

        // for safe ERC20 check of code length at token address
        vm.prank(address(_terminal));

        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }

    function test_WhenTheCallerIsNotItself() external {
        // it will revert

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        vm.expectRevert();
        JBMultiTerminal(address(_terminal)).executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });
    }
}
