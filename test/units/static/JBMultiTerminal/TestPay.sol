// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestPay_Local is JBMultiTerminalSetup {
    uint56 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    address _bene = makeAddr("beneficiary");
    address _native = JBConstants.NATIVE_TOKEN;
    uint32 _nativeCurrency = uint32(uint160(_native));
    address _usdc = makeAddr("USDC");
    uint32 _usdcCurrency = uint32(uint160(_usdc));

    address _mockController = makeAddr("mc");
    IJBPayHook _mockHook = IJBPayHook(makeAddr("hook"));

    // mock erc20 necessary for balance checks
    MockERC20 _mockToken;
    uint256 _mockTokenCurrency;

    function setUp() public {
        super.multiTerminalSetup();

        _mockToken = new MockERC20("testToken", "TT");
        _mockTokenCurrency = uint32(uint160(address(_mockToken)));
    }

    modifier whenNativeTokenIsAccepted() {
        // mock call to JBProjects ownerOf
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(0)));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: JBConstants.NATIVE_TOKEN,
            decimals: 18,
            currency: uint32(uint160(JBConstants.NATIVE_TOKEN))
        });

        // setup: return data
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(returnedRuleset));

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        _;
    }

    modifier whenERC20IsAccepted() {
        // mock call to JBProjects ownerOf
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(0)));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        // mock supports interface call
        mockExpect(
            address(_mockToken),
            abi.encodeCall(IERC165.supportsInterface, (type(IERC20Metadata).interfaceId)),
            abi.encode(true)
        );

        // mock call to token decimals
        mockExpect(address(_mockToken), abi.encodeCall(IERC20Metadata.decimals, ()), abi.encode(6));

        JBAccountingContext[] memory _tokens = new JBAccountingContext[](1);
        _tokens[0] = JBAccountingContext({
            token: address(_mockToken),
            decimals: 6,
            currency: uint32(uint160(address(_mockToken)))
        });

        // setup: return data
        JBRuleset memory ruleset = JBRuleset({
            cycleNumber: 1,
            id: 0,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(ruleset));

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        _;
    }

    function test_WhenTokensReturnedLTMinReturnedTokens() external whenNativeTokenIsAccepted {
        // it will revert UNDER_MIN_RETURNED_TOKENS

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount = JBTokenAmount(_native, 18, uint32(_nativeCurrency), _defaultAmount);
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](0);
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom, (address(this), tokenAmount, _projectId, _bene, bytes(""))
            ),
            abi.encode(returnedRuleset, 0, hookSpecifications)
        );

        mockExpect(address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), abi.encode(0));

        vm.expectRevert(abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_UnderMinReturnedTokens.selector, 0, 1));
        _terminal.pay{value: 1e18}({
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: 1,
            memo: "",
            metadata: ""
        });
    }

    function test_WhenTerminalStoreReturnsTokenCountGTZeroAndHappypath() external whenNativeTokenIsAccepted {
        // it will mint tokens and emit Pay

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount = JBTokenAmount(_native, 18, uint32(_nativeCurrency), _defaultAmount);
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](0);
        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        uint256 _mintAmount = 1e9;

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom, (address(this), tokenAmount, _projectId, _bene, bytes(""))
            ),
            abi.encode(returnedRuleset, _mintAmount, hookSpecifications)
        );

        // mock call to controller (this contract per modifier mock call) mintTokensOf
        mockExpect(
            address(this),
            abi.encodeCall(IJBController.mintTokensOf, (_projectId, _mintAmount, _bene, "", true)),
            abi.encode(_mintAmount)
        );

        // Data for subsequent calls made for balance checks
        bytes[] memory subsequentReturns = new bytes[](2);
        subsequentReturns[0] = abi.encode(0);
        subsequentReturns[1] = abi.encode(_mintAmount);

        // Mock subsequent calls made for balance checks
        mockExpectSubsequent(
            address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), subsequentReturns
        );

        vm.expectEmit();
        emit IJBTerminal.Pay(
            returnedRuleset.id,
            returnedRuleset.cycleNumber,
            _projectId,
            address(this),
            _bene,
            _defaultAmount,
            _mintAmount,
            "",
            bytes(""),
            address(this)
        );
        _terminal.pay{value: 1e18}({
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });
    }

    modifier whenAPayHookIsConfiguredAndHappypath() {
        _;
    }

    function test_GivenThePaidTokenIsAnERC20AndPayHookIsConfigured() external whenERC20IsAccepted {
        // it will increase allowance to the hook and emit HookAfterRecordPay and Pay

        // mint mocked erc20 tokens to this contract
        _mockToken.mint(address(this), _defaultAmount);

        // approve those tokens to the terminal
        _mockToken.approve(address(_terminal), _defaultAmount);

        uint256 _mintAmount = 1e9;

        // set an approval to the pay hook as the terminal
        vm.prank(address(_terminal));
        _mockToken.approve(address(_mockHook), _defaultAmount);

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount =
            JBTokenAmount(address(_mockToken), 6, uint32(_mockTokenCurrency), _defaultAmount);
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](1);
        hookSpecifications[0] = JBPayHookSpecification({hook: _mockHook, amount: _defaultAmount, metadata: ""});

        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom, (address(this), tokenAmount, _projectId, _bene, bytes(""))
            ),
            abi.encode(returnedRuleset, _mintAmount, hookSpecifications)
        );

        // mock call to controller (this contract per modifier mock call) mintTokensOf
        mockExpect(
            address(this),
            abi.encodeCall(IJBController.mintTokensOf, (_projectId, _mintAmount, _bene, "", true)),
            abi.encode(_mintAmount)
        );

        // Needed for hook call
        JBAfterPayRecordedContext memory context = JBAfterPayRecordedContext({
            payer: address(this),
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            amount: tokenAmount,
            forwardedAmount: tokenAmount,
            weight: returnedRuleset.weight,
            newlyIssuedTokenCount: _mintAmount,
            beneficiary: _bene,
            hookMetadata: bytes(""),
            payerMetadata: bytes("")
        });

        // mock call to hook
        mockExpect(address(_mockHook), abi.encodeCall(IJBPayHook.afterPayRecordedWith, (context)), "");

        vm.expectEmit();
        emit IJBTerminal.Pay(
            returnedRuleset.id,
            returnedRuleset.cycleNumber,
            _projectId,
            address(this),
            _bene,
            _defaultAmount,
            _mintAmount,
            "",
            bytes(""),
            address(this)
        );
        vm.expectEmit();
        emit IJBTerminal.HookAfterRecordPay(_mockHook, context, _defaultAmount, address(this));

        // Data for subsequent calls made for balance checks
        bytes[] memory subsequentReturns = new bytes[](2);
        subsequentReturns[0] = abi.encode(0);
        subsequentReturns[1] = abi.encode(_mintAmount);

        // Mock subsequent calls made for balance checks
        mockExpectSubsequent(
            address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), subsequentReturns
        );

        _terminal.pay({
            projectId: _projectId,
            token: address(_mockToken),
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: _mintAmount,
            memo: "",
            metadata: ""
        });
    }

    function test_GivenThePaidTokenIsNativeAndPayHookIsConfigured() external whenNativeTokenIsAccepted {
        // it will send ETH to the hook and emit HookAfterRecordPay and Pay

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount = JBTokenAmount(_native, 18, uint32(_nativeCurrency), _defaultAmount);
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](1);
        hookSpecifications[0] = JBPayHookSpecification({hook: _mockHook, amount: _defaultAmount, metadata: ""});

        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        uint256 _mintAmount = 1e9;

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom, (address(this), tokenAmount, _projectId, _bene, bytes(""))
            ),
            abi.encode(returnedRuleset, _mintAmount, hookSpecifications)
        );

        // mock call to controller (this contract per modifier mock call) mintTokensOf
        mockExpect(
            address(this),
            abi.encodeCall(IJBController.mintTokensOf, (_projectId, _mintAmount, _bene, "", true)),
            abi.encode(_mintAmount)
        );

        // Needed for hook call
        JBAfterPayRecordedContext memory context = JBAfterPayRecordedContext({
            payer: address(this),
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            amount: tokenAmount,
            forwardedAmount: tokenAmount,
            weight: returnedRuleset.weight,
            newlyIssuedTokenCount: _mintAmount,
            beneficiary: _bene,
            hookMetadata: bytes(""),
            payerMetadata: bytes("")
        });

        // mock call to hook (including msg.value)
        mockExpect(address(_mockHook), abi.encodeCall(IJBPayHook.afterPayRecordedWith, (context)), "");

        // Data for subsequent calls made for balance checks
        bytes[] memory subsequentReturns = new bytes[](2);
        subsequentReturns[0] = abi.encode(0);
        subsequentReturns[1] = abi.encode(_mintAmount);

        // Mock subsequent calls made for balance checks
        mockExpectSubsequent(
            address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), subsequentReturns
        );

        vm.expectEmit();
        emit IJBTerminal.Pay(
            returnedRuleset.id,
            returnedRuleset.cycleNumber,
            _projectId,
            address(this),
            _bene,
            _defaultAmount,
            _mintAmount,
            "",
            bytes(""),
            address(this)
        );

        vm.expectEmit();
        emit IJBTerminal.HookAfterRecordPay(_mockHook, context, _defaultAmount, address(this));

        _terminal.pay{value: 1e18}({
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });
    }

    function test_WhenTheProjectDNHAccountingContextForTheToken() external {
        // it will revert TOKEN_NOT_ACCEPTED

        mockExpect(address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), abi.encode(0));

        vm.expectRevert(abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_TokenNotAccepted.selector, _native));
        _terminal.pay{value: 1e18}({
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });
    }

    /* function test_WhenTheTerminalsTokenEqNativeToken() external {
        // it will use msg.value
        // covered above
    } */

    function test_WhenTheTerminalsTokenEqNativeTokenAndMsgvalueEqZero() external {
        // it will revert NO_MSG_VALUE_ALLOWED

        mockExpect(address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), abi.encode(0));

        vm.expectRevert(abi.encodeWithSelector(JBMultiTerminal.JBMultiTerminal_TokenNotAccepted.selector, _native));
        _terminal.pay{value: 0}({
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });
    }

    function test_WhenTheTerminalIsCallingItself() external whenNativeTokenIsAccepted {
        // it will not transfer

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount = JBTokenAmount(_native, 18, uint32(_nativeCurrency), _defaultAmount);
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](0);

        JBRuleset memory returnedRuleset = JBRuleset({
            cycleNumber: 1,
            id: 1,
            basedOnId: 0,
            start: 0,
            duration: 0,
            weight: 0,
            decayPercent: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom, (address(_terminal), tokenAmount, _projectId, _bene, bytes(""))
            ),
            abi.encode(returnedRuleset, 0, hookSpecifications)
        );

        // Data for subsequent calls made for balance checks
        bytes[] memory subsequentReturns = new bytes[](2);
        subsequentReturns[0] = abi.encode(0);
        subsequentReturns[1] = abi.encode(0);

        // Mock subsequent calls made for balance checks
        mockExpectSubsequent(
            address(tokens), abi.encodeCall(IJBTokens.totalBalanceOf, (_bene, _projectId)), subsequentReturns
        );

        vm.deal(address(_terminal), _defaultAmount);
        vm.prank(address(_terminal));
        _terminal.pay{value: _defaultAmount}({
            projectId: _projectId,
            token: _native,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: 0,
            memo: "",
            metadata: ""
        });
    }

    // accept funds with permit2 has been extensively tested in other units
    /* modifier whenPayMetadataContainsPermitData() {
        _;
    }

    function test_GivenThePermitAllowanceLtAmount() external whenPayMetadataContainsPermitData {
        // it will revert PERMIT_ALLOWANCE_NOT_ENOUGH
    }

    function test_GivenPermitAllowanceIsGood() external whenPayMetadataContainsPermitData {
        // it will set permit allowance to spend tokens for user via permit2
    } */
}
