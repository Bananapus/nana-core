// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestPay_Local is JBMultiTerminalSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    address _bene = makeAddr("beneficiary");
    address _native = JBConstants.NATIVE_TOKEN;
    uint256 _nativeCurrency = uint32(uint160(_native));
    address _usdc = makeAddr("USDC");
    uint256 _usdcCurrency = uint32(uint160(_usdc));

    address _mockController = makeAddr("mc");
    IJBPayHook _mockHook = IJBPayHook(makeAddr("hook"));

    function setUp() public {
        super.multiTerminalSetup();
    }

    modifier whenNativeTokenIsAccepted() {
        // mock call to JBProjects ownerOf
        mockExpect(address(projects), abi.encodeCall(IERC721.ownerOf, (_projectId)), abi.encode(address(0)));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        address[] memory _tokens = new address[](1);
        _tokens[0] = _native;

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

        // mock call to token decimals
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20Metadata.decimals, ()),
            abi.encode(6)
        );

        address[] memory _tokens = new address[](1);
        _tokens[0] = _usdc;

        _terminal.addAccountingContextsFor(_projectId, _tokens);

        _;
    }

    function test_WhenTokensReturnedLTMinReturnedTokens() external whenNativeTokenIsAccepted {
        // it will revert UNDER_MIN_RETURNED_TOKENS

        // needed for next mock call returns
        JBTokenAmount memory tokenAmount = JBTokenAmount(_native, _defaultAmount, 18, uint32(_nativeCurrency));
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](0);
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

        // mock call to JBTerminalStore recordPaymentFrom
        mockExpect(
            address(store),
            abi.encodeCall(
                IJBTerminalStore.recordPaymentFrom, (address(this), tokenAmount, _projectId, _bene, bytes(""))
            ),
            abi.encode(returnedRuleset, 0, hookSpecifications)
        );

        vm.expectRevert(abi.encodeWithSignature("UNDER_MIN_RETURNED_TOKENS()"));
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
        JBTokenAmount memory tokenAmount = JBTokenAmount(_native, _defaultAmount, 18, uint32(_nativeCurrency));
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](0);
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

    function test_GivenThePaidTokenIsAnERC20() external whenERC20IsAccepted() {
        // it will increase allowance to the hook and emit HookAfterRecordPay and Pay

        uint256 _mintAmount = 1e9;

        // mock call to usdc balanceOf
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20.balanceOf, (address(_terminal))),
            abi.encode(_defaultAmount)
        );

        // mock call to usdc allowance
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20.allowance, (address(this), address(_terminal))),
            abi.encode(_defaultAmount)
        );

        // mock transferFrom
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20.transferFrom, (address(this), address(_terminal), _defaultAmount)),
            abi.encode(true)
        );

        // mock hook allowance call
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20.allowance, (address(_terminal), address(_mockHook))),
            abi.encode(_defaultAmount)
        );

        // mock the subsequent approval call
        mockExpect(
            _usdc,
            abi.encodeCall(IERC20.approve, (address(_mockHook), _defaultAmount * 2)),
            abi.encode(true)
        );

        // needed for next mock call returns
        /// @notice the value here is zero as self balance of the terminal is called twice and we cant separately mock
        /// the subsequent second call with the correct value _defaultAmount (forge limitation).
        JBTokenAmount memory tokenAmount = JBTokenAmount(_usdc, 0, 6, uint32(_usdcCurrency));
        JBPayHookSpecification[] memory hookSpecifications = new JBPayHookSpecification[](1);
        hookSpecifications[0] = JBPayHookSpecification({
            hook: _mockHook,
            amount: _defaultAmount,
            metadata: ""
        });

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

        /* // Needed for hook call
        JBAfterPayRecordedContext memory context = JBAfterPayRecordedContext({
            payer: address(this),
            projectId: _projectId,
            rulesetId: returnedRuleset.id,
            amount: tokenAmount,
            forwardedAmount: tokenAmount,
            weight: returnedRuleset.weight,
            projectTokenCount: _mintAmount,
            beneficiary: _bene,
            hookMetadata: bytes(""),
            payerMetadata: bytes("")
        });

        // mock call to hook
        mockExpect(
            address(_mockHook),
            abi.encodeCall(IJBPayHook.afterPayRecordedWith, (context)),
            ""
        ); */

        /* vm.expectEmit();
        emit IJBTerminal.Pay(
            returnedRuleset.id,
            returnedRuleset.cycleNumber,
            _projectId,
            address(this),
            _bene,
            0,
            _mintAmount,
            "",
            bytes(""),
            address(this)
        ); */
        _terminal.pay({
            projectId: _projectId,
            token: _usdc,
            amount: _defaultAmount,
            beneficiary: _bene,
            minReturnedTokens: _mintAmount,
            memo: "",
            metadata: ""
        });
    }

    function test_GivenThePaidTokenIsNative() external whenAPayHookIsConfiguredAndHappypath {
        // it will send ETH to the hook and emit HookAfterRecordPay and Pay
    }

    function test_WhenTheProjectDNHAccountingContextForTheToken() external {
        // it will revert TOKEN_NOT_ACCEPTED
    }

    function test_WhenTheTerminalsTokenEqNativeToken() external {
        // it will use msg.value
    }

    function test_WhenTheTerminalsTokenEqNativeTokenAndMsgvalueEqZero() external {
        // it will revert NO_MSG_VALUE_ALLOWED
    }

    function test_WhenTheTerminalIsCallingItself() external {
        // it will not transfer
    }

    modifier whenPayMetadataContainsPermitData() {
        _;
    }

    function test_GivenThePermitAllowanceLtAmount() external whenPayMetadataContainsPermitData {
        // it will revert PERMIT_ALLOWANCE_NOT_ENOUGH
    }

    function test_GivenPermitAllowanceIsGood() external whenPayMetadataContainsPermitData {
        // it will set permit allowance to spend tokens for user via permit2
    }
}
