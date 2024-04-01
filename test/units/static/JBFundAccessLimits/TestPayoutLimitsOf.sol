// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestPayoutLimitsOf_Local is JBFundAccessSetup {
    uint256 _projectId = 1;
    uint256 _ruleset = block.timestamp;
    uint256 _payoutLimit = 1e18;
    uint256 _payoutLimit2 = 1e6;
    uint256 _currency = uint32(uint160(JBConstants.NATIVE_TOKEN));
    address _terminal = address(1);
    address _terminal2 = address(2);
    address _someToken = makeAddr("sometoken");

    function setUp() public {
        super.fundAccessSetup();
    }

    modifier whenAProjectHasPayoutLimits() {
        // Fund Access config
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](2);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](2);
            _payoutLimits[0] =
                JBCurrencyAmount({amount: _payoutLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            // Specify a second payout limit.
            _payoutLimits[1] = JBCurrencyAmount({amount: _payoutLimit2, currency: uint32(uint160(_someToken))});

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](0);

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });

            _fundAccessLimitGroup[1] = JBFundAccessLimitGroup({
                terminal: address(_terminal2),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        bytes memory _controllerCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _return = abi.encode(address(this));

        mockExpect(address(directory), _controllerCall, _return);

        _fundAccess.setFundAccessLimitsFor(_projectId, _ruleset, _fundAccessLimitGroup);
        _fundAccess.setFundAccessLimitsFor(_projectId, _ruleset + 1, _fundAccessLimitGroup);
        _;
    }

    function test_GivenTheyAreConfiguredForASpecificToken() external whenAProjectHasPayoutLimits {
        // it will return them

        JBCurrencyAmount[] memory payoutLimits =
            _fundAccess.payoutLimitsOf(_projectId, _ruleset, _terminal, JBConstants.NATIVE_TOKEN);

        assertEq(payoutLimits[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(payoutLimits[0].amount, _payoutLimit);
        assertEq(payoutLimits[1].currency, uint32(uint160(_someToken)));
        assertEq(payoutLimits[1].amount, _payoutLimit2);
    }

    function test_GivenTheyAreConfiguredForASpecificTerminal() external whenAProjectHasPayoutLimits {
        // it will return them
        JBCurrencyAmount[] memory payoutLimits =
            _fundAccess.payoutLimitsOf(_projectId, _ruleset, _terminal2, JBConstants.NATIVE_TOKEN);

        assertEq(payoutLimits[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(payoutLimits[0].amount, _payoutLimit);
        assertEq(payoutLimits[1].currency, uint32(uint160(_someToken)));
        assertEq(payoutLimits[1].amount, _payoutLimit2);
    }

    function test_GivenTheyAreConfiguredForASpecificRulesetId() external whenAProjectHasPayoutLimits {
        // it will return them
        JBCurrencyAmount[] memory payoutLimits =
            _fundAccess.payoutLimitsOf(_projectId, _ruleset + 1, _terminal2, JBConstants.NATIVE_TOKEN);

        assertEq(payoutLimits[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(payoutLimits[0].amount, _payoutLimit);
        assertEq(payoutLimits[1].currency, uint32(uint160(_someToken)));
        assertEq(payoutLimits[1].amount, _payoutLimit2);
    }
}
