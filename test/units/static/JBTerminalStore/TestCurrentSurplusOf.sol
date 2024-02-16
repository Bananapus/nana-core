// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTerminalStoreSetup} from "./JBTerminalStoreSetup.sol";

contract TestCurrentSurplusOf_Local is JBTerminalStoreSetup {
    using JBRulesetMetadataResolver for JBRulesetMetadata;

    uint256 _projectId = 1;
    uint256 _balance = 1e18;

    // Mocks
    IJBTerminal _terminal = IJBTerminal(makeAddr("terminal"));
    IJBToken _token = IJBToken(makeAddr("token"));
    IJBController _controller = IJBController(makeAddr("controller"));
    IJBFundAccessLimits _accessLimits = IJBFundAccessLimits(makeAddr("funds"));

    uint32 _currency = uint32(uint160(address(_token)));
    address _nativeAddress = JBConstants.NATIVE_TOKEN;
    uint32 _nativeCurrency = uint32(uint160(JBConstants.NATIVE_TOKEN));

    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenProjectHasBalance() {
        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(_terminal), uint256(1)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set balance
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(_terminal), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance);
        _;
    }

    function test_GivenSurplusRequiresDecimalAdjustmentAndAccountingCurrencyMatchesTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will adjust surplus to target decimals without conversion
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);

        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.controllerOf, (_projectId)),
            abi.encode(address(_controller))
        );

        // mock call to controller FUND_ACCESS_LIMITS
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // mock call to fundAccessLimits payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_payoutLimits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        uint256 currentSurplus = _store.currentSurplusOf(address(_terminal), _projectId, _contexts, 6, _currency);

        // assert correct calcs
        uint256 expectedSurplus = (1e18 - 1e17) / 10 ** (18 - 6);
        assertEq(expectedSurplus, currentSurplus);
    }

    function test_GivenSurplusRequiresDecimalAdjustmentAndAccountingCurrencyDoesNotMatchTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will convert surplus to target currency with decimal adjustment
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);

        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.controllerOf, (_projectId)),
            abi.encode(address(_controller))
        );

        // mock call to controller FUND_ACCESS_LIMITS
        bytes memory _accessLimitsCall = abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ());
        bytes memory _accessLimitsReturn = abi.encode(_accessLimits);
        mockExpect(address(_controller), _accessLimitsCall, _accessLimitsReturn);

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // mock call to fundAccessLimits payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_payoutLimits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // mock call to JBPrices pricePerUnitOf
        bytes memory _pricePerCall =
            abi.encodeCall(IJBPrices.pricePerUnitOf, (_projectId, _currency, _nativeCurrency, 18));
        bytes memory _pricePerReturn = abi.encode(uint256(1));
        mockExpect(address(prices), _pricePerCall, _pricePerReturn);

        uint256 currentSurplus = _store.currentSurplusOf(address(_terminal), _projectId, _contexts, 6, _nativeCurrency);

        // assert correct calcs
        uint256 expectedSurplus = ((1e18 - 1e17) * 1e18) / 10 ** (18 - 6);
        assertEq(expectedSurplus, currentSurplus);
    }

    function test_GivenAccountingCurrencyMatchesTargetCurrency() external whenProjectHasBalance {
        // it will return standard surplus

        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);

        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.controllerOf, (_projectId)),
            abi.encode(address(_controller))
        );

        // mock call to controller FUND_ACCESS_LIMITS
        mockExpect(
            address(_controller), abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ()), abi.encode(_accessLimits)
        );

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // mock call to fundAccessLimits payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_payoutLimits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        uint256 currentSurplus = _store.currentSurplusOf(address(_terminal), _projectId, _contexts, 18, _currency);

        // assert correct calcs
        uint256 expectedSurplus = 1e18 - 1e17;
        assertEq(expectedSurplus, currentSurplus);
    }

    function test_GivenAccountingCurrencyDoesNotMatchTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will convert surplus to target currency without decimal adjustment
        JBAccountingContext[] memory _contexts = new JBAccountingContext[](1);

        _contexts[0] = JBAccountingContext({token: address(_token), decimals: 18, currency: _currency});

        // JBRulesets calldata
        JBRuleset memory _returnedRuleset = JBRuleset({
            cycleNumber: block.timestamp,
            id: block.timestamp,
            basedOnId: 0,
            start: block.timestamp,
            duration: block.timestamp + 1000,
            weight: 1e18,
            decayRate: 0,
            approvalHook: IJBRulesetApprovalHook(address(0)),
            metadata: 0
        });

        // mock call to JBRulesets currentOf
        mockExpect(address(rulesets), abi.encodeCall(IJBRulesets.currentOf, (_projectId)), abi.encode(_returnedRuleset));

        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.controllerOf, (_projectId)),
            abi.encode(address(_controller))
        );

        // mock call to controller FUND_ACCESS_LIMITS
        bytes memory _accessLimitsCall = abi.encodeCall(IJBController.FUND_ACCESS_LIMITS, ());
        bytes memory _accessLimitsReturn = abi.encode(_accessLimits);
        mockExpect(address(_controller), _accessLimitsCall, _accessLimitsReturn);

        JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
        _payoutLimits[0] = JBCurrencyAmount({amount: 1e17, currency: _currency});

        // mock call to fundAccessLimits payoutLimitsOf
        bytes memory _payoutLimitsCall = abi.encodeCall(
            IJBFundAccessLimits.payoutLimitsOf, (_projectId, block.timestamp, address(_terminal), address(_token))
        );
        bytes memory _payoutLimitsReturn = abi.encode(_payoutLimits);
        mockExpect(address(_accessLimits), _payoutLimitsCall, _payoutLimitsReturn);

        // mock call to JBPrices pricePerUnitOf
        bytes memory _pricePerCall =
            abi.encodeCall(IJBPrices.pricePerUnitOf, (_projectId, _currency, _nativeCurrency, 18));
        bytes memory _pricePerReturn = abi.encode(uint256(1));
        mockExpect(address(prices), _pricePerCall, _pricePerReturn);

        uint256 currentSurplus = _store.currentSurplusOf(address(_terminal), _projectId, _contexts, 18, _nativeCurrency);

        // assert correct calcs
        uint256 expectedSurplus = (1e18 - 1e17) * 1e18;
        assertEq(expectedSurplus, currentSurplus);
    }

    function test_GivenAPayoutLimitRequiresDecimalAdjustmentAndPayoutLimitCurrencyMatchesTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will adjust payout limit to target decimals without conversion
    }

    function test_GivenPayoutLimitCurrencyThatRequiresDecimalAdjustmentDoesNotMatchTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will convert payout limit to target currency with decimal adjustment
    }

    function test_GivenPayoutLimitCurrencyMatchesTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will return standard surplus
    }

    function test_GivenPayoutLimitCurrencyDoesNotMatchTargetCurrency()
        external
        whenProjectHasBalance
    {
        // it will convert payout limit target currency without decimal adjustment
    }

    function test_GivenCumulativePayoutLimitGreaterThanSurplus() external {
        // it will decrease surplus by payout limit amount
    }

    function test_GivenCumulativePayoutLimitNotGreaterThanSurplus() external {
        // it will return zero
    }
}
