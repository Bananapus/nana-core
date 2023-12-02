// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

contract TestDelegates_Local is TestBaseWorkflow {
    uint8 private constant _WEIGHT_DECIMALS = 18;
    uint8 private constant _NATIVE_TOKEN_DECIMALS = 18;
    uint256 private constant _WEIGHT = 1000 * 10 ** _WEIGHT_DECIMALS;
    uint256 private constant _DATA_SOURCE_WEIGHT = 2000 * 10 ** _WEIGHT_DECIMALS;
    address private constant _DATA_SOURCE = address(bytes20(keccak256("datahook")));
    bytes private constant _PAYER_METADATA = bytes("Some payer metadata");

    IJBController private _controller;
    IJBTerminal private _terminal;
    address private _projectOwner;
    address private _beneficiary;
    address private _payer;

    uint256 _projectId;

    function setUp() public override {
        super.setUp();

        _controller = jbController();
        _projectOwner = multisig();
        _beneficiary = beneficiary();
        _payer = address(1_234_567);
        _terminal = jbMultiTerminal();

        JBRulesetData memory _data = JBRulesetData({
            duration: 0,
            weight: _WEIGHT,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0))
        });

        JBRulesetMetadata memory _metadata = JBRulesetMetadata({
            global: JBGlobalRulesetMetadata({
                allowSetTerminals: false,
                allowSetController: false,
                pauseTransfers: false
            }),
            reservedRate: 0,
            redemptionRate: 0,
            baseCurrency: uint32(uint160(JBTokenList.Native)),
            pausePay: false,
            allowDiscretionaryMinting: false,
            allowTerminalMigration: false,
            allowControllerMigration: false,
            holdFees: false,
            useTotalSurplusForRedemptions: false,
            useDataHookForPay: true,
            useDataHookForRedeem: true,
            dataHook: _DATA_SOURCE,
            metadata: 0
        });

        // Package up cycle config.
        JBRulesetConfig[] memory _rulesetConfig = new JBRulesetConfig[](1);
        _rulesetConfig[0].mustStartAtOrAfter = 0;
        _rulesetConfig[0].data = _data;
        _rulesetConfig[0].metadata = _metadata;
        _rulesetConfig[0].splitGroups = new JBSplitGroup[](0);
        _rulesetConfig[0].fundAccessLimitGroup = new JBFundAccessLimitGroup[](0);

        JBTerminalConfig[] memory _terminalConfigurations = new JBTerminalConfig[](1);
        JBAccountingContextConfig[] memory _accountingContexts = new JBAccountingContextConfig[](1);
        _accountingContexts[0] = JBAccountingContextConfig({
            token: JBTokenList.Native,
            standard: JBTokenStandards.NATIVE
        });
        _terminalConfigurations[0] =
            JBTerminalConfig({terminal: _terminal, accountingContextConfigs: _accountingContexts});

        _projectId = _controller.launchProjectFor({
            owner: _projectOwner,
            projectMetadata: JBProjectMetadata({content: "myIPFSHash", domain: 1}),
            rulesetConfigurations: _rulesetConfig,
            terminalConfigurations: _terminalConfigurations,
            memo: ""
        });
    }

    function testPayHooks(uint256 _numberOfAllocations, uint256 _nativePayAmount) public {
        // Bound the number of allocations to a reasonable amount.
        _numberOfAllocations = bound(_numberOfAllocations, 1, 20);
        // Make sure the amount of tokens generated fits in a register, and that each allocation can get some.
        _nativePayAmount =
            bound(_nativePayAmount, _numberOfAllocations, type(uint256).max / _DATA_SOURCE_WEIGHT);

        // epa * weight / epad < max*epad/weight

        // Keep a reference to the allocations.
        JBPayHookPayload[] memory _allocations = new JBPayHookPayload[](_numberOfAllocations);

        // Keep a refernce to the amounts that'll be allocated.
        uint256[] memory _payDelegateAmounts = new uint256[](_numberOfAllocations);

        // Keep a reference to the amount that'll be paid and allocated.
        uint256 _totalToAllocate = _nativePayAmount;

        // Spread the paid amount through all allocations, in various chunks, omitted the last entry.
        for (uint256 i; i < _numberOfAllocations - 1; i++) {
            _payDelegateAmounts[i] = _totalToAllocate / (_payDelegateAmounts.length * 2);
            _totalToAllocate -= _payDelegateAmounts[i];
        }

        // Send the rest to the last entry.
        _payDelegateAmounts[_payDelegateAmounts.length - 1] = _totalToAllocate;

        // Keep a reference to the current funding cycle.
        (JBRuleset memory _fundingCycle,) = _controller.currentRulesetOf(_projectId);

        // Iterate through each allocation.
        for (uint256 i = 0; i < _numberOfAllocations; i++) {
            // Make up an address for the hook.
            address _hookAddress = address(bytes20(keccak256(abi.encodePacked("PayHook", i))));

            // Send along some metadata to the pay hook.
            bytes memory _dataHookMetadata = bytes("Some data source metadata");

            // Package up the hook allocation struct.
            _allocations[i] = JBPayHookPayload(
                IJBPayHook(_hookAddress), _payDelegateAmounts[i], _dataHookMetadata
            );

            // Keep a reference to the data that'll be received by the hook.
            JBDidPayData memory _didPayData = JBDidPayData({
                payer: _payer,
                projectId: _projectId,
                currentRulesetId: _fundingCycle.rulesetId,
                amount: JBTokenAmount(
                    JBTokenList.Native,
                    _nativePayAmount,
                    _terminal.accountingContextForTokenOf(_projectId, JBTokenList.Native).decimals,
                    _terminal.accountingContextForTokenOf(_projectId, JBTokenList.Native).currency
                    ),
                forwardedAmount: JBTokenAmount(
                    JBTokenList.Native,
                    _payDelegateAmounts[i],
                    _terminal.accountingContextForTokenOf(_projectId, JBTokenList.Native).decimals,
                    _terminal.accountingContextForTokenOf(_projectId, JBTokenList.Native).currency
                    ),
                weight: _WEIGHT,
                projectTokenCount: PRBMath.mulDiv(
                    _nativePayAmount, _DATA_SOURCE_WEIGHT, 10 ** _NATIVE_TOKEN_DECIMALS
                    ),
                beneficiary: _beneficiary,
                dataHookMetadata: _dataHookMetadata,
                payerMetadata: _PAYER_METADATA
            });

            // Mock the hook
            vm.mockCall(
                _hookAddress,
                abi.encodeWithSelector(IJBPayHook.didPay.selector),
                abi.encode(_didPayData)
            );

            // Assert that the hook gets called with the expected value
            vm.expectCall(
                _hookAddress,
                _payDelegateAmounts[i],
                abi.encodeWithSelector(IJBPayHook.didPay.selector, _didPayData)
            );

            // Expect an event to be emitted for every hook
            vm.expectEmit(true, true, true, true);
            emit HookDidPay(IJBPayHook(_hookAddress), _didPayData, _payDelegateAmounts[i], _payer);
        }

        vm.mockCall(
            _DATA_SOURCE,
            abi.encodeWithSelector(IJBRulesetDataHook.payParams.selector),
            abi.encode(_DATA_SOURCE_WEIGHT, _allocations)
        );

        vm.deal(_payer, _nativePayAmount);
        vm.prank(_payer);

        // Pay the project such that the `_beneficiary` receives project tokens.
        _terminal.pay{value: _nativePayAmount}({
            projectId: _projectId,
            amount: _nativePayAmount,
            token: JBTokenList.Native,
            beneficiary: _beneficiary,
            minReturnedTokens: 0,
            memo: "Forge Test",
            metadata: _PAYER_METADATA
        });
    }

    event HookDidPay(
        IJBPayHook indexed hook, JBDidPayData data, uint256 hookdAmount, address caller
    );
}
