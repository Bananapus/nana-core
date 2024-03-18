// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestExecutePayout_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    uint256 _noProject = 0;
    uint256 _lockedUntil = 0;
    uint256 _defaultAmount = 1e18;
    uint256 _fee = 25;
    address _hook = makeAddr("splithook");
    address payable _bene = payable(makeAddr("beneficiary"));
    address payable _noBene = payable(address(0));

    address _native = JBConstants.NATIVE_TOKEN;
    // uint256 _nativeCurrency = uint32(uint160(_native));
    address _usdc = makeAddr("USDC");
    // uint256 _usdcCurrency = uint32(uint160(_usdc));

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
        mockExpect(address(_hook), abi.encodeCall(IJBSplitHook.processSplitWith, (context)), abi.encode());

        _terminal.executePayout({
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
        mockExpect(address(_hook), abi.encodeCall(IJBSplitHook.processSplitWith, (context)), abi.encode());

        _terminal.executePayout({
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

        // mock call to FeelessAddresses isFeeless
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (_hook)), abi.encode(false));

        vm.expectRevert(bytes("400_1"));
        _terminal.executePayout({
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
        mockExpect(address(feelessAddresses), abi.encodeCall(IJBFeelessAddresses.isFeeless, (address(this))), abi.encode(false));

        JBSplit memory _splitMemory = JBSplit({
            preferAddToBalance: false,
            percent: JBConstants.SPLITS_TOTAL_PERCENT,
            projectId: _noProject,
            beneficiary: _noBene,
            lockedUntil: _lockedUntil,
            hook: IJBSplitHook(address(0))
        });

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);

        // Create the context to send to the split hook.
        JBSplitHookContext memory context = JBSplitHookContext({
            token: _usdc,
            amount: _defaultAmount - taxedAmount, // It will call with taxed amount
            decimals: 0,
            projectId: _noProject,
            groupId: uint256(uint160(_usdc)),
            split: _splitMemory
        });

        /* // mock call to hooks processSplitWith
        mockExpect(address(_hook), abi.encodeCall(IJBSplitHook.processSplitWith, (context)), abi.encode()); */

        // mock call to usdc transfer
        mockExpect(
            address(_usdc),
            abi.encodeCall(IERC20.transfer, (address(this), _defaultAmount - taxedAmount)),
            abi.encode(true)
        );

        // for safe ERC20 check of code length at token address
        vm.etch(_usdc, abi.encode(1));

        _terminal.executePayout({
            split: _splitMemory,
            projectId: _noProject,
            token: _usdc,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });

    }

    /* function test_GivenThePayoutTokenIsNative() external whenASplitHookIsConfigured {
        // it will send eth in msgvalue
        // this case was checked above
    }

    modifier whenASplitProjectIdIsConfigured() {
        _;
    } */

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

        uint256 taxedAmount = JBFees.feeAmountIn(_defaultAmount, _fee);

        // Create the context to send to the split hook.
        JBSplitHookContext memory context = JBSplitHookContext({
            token: _native,
            amount: _defaultAmount - taxedAmount, // It will call with taxed amount
            decimals: 0,
            projectId: _projectId,
            groupId: uint256(uint160(_native)),
            split: _splitMemory
        });

        vm.expectRevert(bytes("404_2"));
        vm.prank(address(_terminal));
        _terminal.executePayout({
            split: _splitMemory,
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            originalMessageSender: address(this)
        });

    }

    function test_GivenPreferAddToBalanceEQTrueAndTerminalEQThisAddress() external {
        // it will call _addToBalanceOf internal
    }

    function test_GivenPreferAddToBalanceEQTrueAndTerminalEQAnotherAddress() external {
        // it will call that terminals addToBalanceOf
    }

    function test_GivenPreferAddToBalanceDNEQTrueAndTerminalEQThisAddress() external {
        // it will call internal _pay
    }

    function test_GivenPreferAddToBalanceDNEQTrueAndTerminalEQAnotherAddress()
        external
    {
        // it will call that terminals pay function
    }

    modifier whenABeneficiaryIsConfigured() {
        _;
    }

    function test_GivenBeneficiaryEQFeeless() external whenABeneficiaryIsConfigured {
        // it will payout to the beneficiary without taking fees
    }

    function test_GivenBeneficiaryDNEQFeeless() external whenABeneficiaryIsConfigured {
        // it will payout to the beneficiary incurring fee
    }

    function test_WhenThereIsNoBeneficiarySplitHookOrProjectToPay() external {
        // it will payout msgSender
    }

    function test_WhenThereAreLeftoverPayoutFunds() external {
        // it will payout the rest to the project owner
    }

    /* fallback() external payable {} */

}
