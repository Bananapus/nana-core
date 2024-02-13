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

    function setUp() public {
        super.terminalStoreSetup();
    }

    modifier whenSurplusRequiresDecimalAdjustment() {
        // Find the storage slot
        bytes32 balanceOfSlot = keccak256(abi.encode(address(_terminal), uint256(1)));
        bytes32 projectSlot = keccak256(abi.encode(_projectId, uint256(balanceOfSlot)));
        bytes32 slot = keccak256(abi.encode(address(_token), uint256(projectSlot)));

        bytes32 balanceBytes = bytes32(_balance);

        // Set direct price feed
        vm.store(address(_store), slot, balanceBytes);

        // Ensure balance is set correctly
        uint256 _balanceCallReturn = _store.balanceOf(address(_terminal), _projectId, address(_token));
        assertEq(_balanceCallReturn, _balance);
        _;
    }

    function test_GivenSurplusRequiresDecimalAdjustmentAndAccountingCurrencyMatchesTargetCurrency()
        external
        whenSurplusRequiresDecimalAdjustment
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
        bytes memory _currentOfCall = abi.encodeCall(IJBRulesets.currentOf, (_projectId));
        bytes memory _currentOfReturn = abi.encode(_returnedRuleset);
        mockExpect(address(rulesets), _currentOfCall, _currentOfReturn);

        // mock call to JBDirectory controllerOf
        bytes memory _controllerOfCall = abi.encodeCall(IJBDirectory.controllerOf, (_projectId));
        bytes memory _controllerOfReturn = abi.encode(address(_controller));
        mockExpect(address(directory), _controllerOfCall, _controllerOfReturn);

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

        uint256 currentSurplus = _store.currentSurplusOf(address(_terminal), _projectId, _contexts, 6, _currency);

        // assert correct calcs
        uint256 expectedSurplus = (1e18 - 1e17) / 10 ** (18 - 6);
        assertEq(expectedSurplus, currentSurplus);
    }

    function test_GivenSurplusRequiresDecimalAdjustmentAndAccountingCurrencyDoesNotMatchTargetCurrency()
        external
        whenSurplusRequiresDecimalAdjustment
    {
        // it will convert surplus to target currency with decimal adjustment
    }

    modifier whenSurplusDoesNotRequireDecimalAdjustment() {
        _;
    }

    function test_GivenAccountingCurrencyMatchesTargetCurrency() external whenSurplusDoesNotRequireDecimalAdjustment {
        // it will return standard surplus
    }

    function test_GivenAccountingCurrencyDoesNotMatchTargetCurrency()
        external
        whenSurplusDoesNotRequireDecimalAdjustment
    {
        // it will convert surplus to target currency without decimal adjustment
    }

    modifier givenAPayoutLimitRequiresDecimalAdjustment() {
        _;
    }

    function test_GivenAPayoutLimitRequiresDecimalAdjustmentAndPayoutLimitCurrencyMatchesTargetCurrency()
        external
        givenAPayoutLimitRequiresDecimalAdjustment
    {
        // it will adjust payout limit to target decimals without conversion
    }

    function test_GivenPayoutLimitCurrencyThatRequiresDecimalAdjustmentDoesNotMatchTargetCurrency()
        external
        givenAPayoutLimitRequiresDecimalAdjustment
    {
        // it will convert payout limit to target currency with decimal adjustment
    }

    modifier givenAPayoutLimitDoesNotRequireDecimalAdjustment() {
        _;
    }

    function test_GivenPayoutLimitCurrencyMatchesTargetCurrency()
        external
        givenAPayoutLimitDoesNotRequireDecimalAdjustment
    {
        // it will return standard surplus
    }

    function test_GivenPayoutLimitCurrencyDoesNotMatchTargetCurrency()
        external
        givenAPayoutLimitDoesNotRequireDecimalAdjustment
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
