// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestSurplusAllowancesOf_Local is JBFundAccessSetup {
    uint256 _projectId = 1;
    address _terminal = address(1);
    address _terminal2 = address(2);
    address _someToken = makeAddr("someToken");

    function setUp() public {
        super.fundAccessSetup();
    }

    modifier whenAProjectHasSpecifiedSurplusAllowances() {
        bytes memory _controllerCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _return = abi.encode(address(this));

        mockExpect(address(directory), _controllerCall, _return);

        // Fund Access config
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](2);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](0);

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](2);
            _surplusAllowances[0] =
                JBCurrencyAmount({amount: 1e18, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            _surplusAllowances[1] = JBCurrencyAmount({amount: 2e18, currency: uint32(uint160(_someToken))});

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: _terminal,
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });

            _fundAccessLimitGroup[1] = JBFundAccessLimitGroup({
                terminal: _terminal2,
                token: _someToken,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        _fundAccess.setFundAccessLimitsFor(_projectId, block.timestamp, _fundAccessLimitGroup);
        _fundAccess.setFundAccessLimitsFor(_projectId, block.timestamp + 1, _fundAccessLimitGroup);

        _;
    }

    function test_GivenTheyAreSpecifiedForASpecificRuleset() external whenAProjectHasSpecifiedSurplusAllowances {
        // it will return them

        JBCurrencyAmount[] memory surplusLimits =
            _fundAccess.surplusAllowancesOf(_projectId, block.timestamp, _terminal, JBConstants.NATIVE_TOKEN);

        JBCurrencyAmount[] memory surplusLimits2 =
            _fundAccess.surplusAllowancesOf(_projectId, block.timestamp + 1, _terminal, JBConstants.NATIVE_TOKEN);

        assertEq(surplusLimits[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(surplusLimits[0].amount, 1e18);
        assertEq(surplusLimits[1].currency, uint32(uint160(_someToken)));
        assertEq(surplusLimits[1].amount, 2e18);

        assertEq(surplusLimits2[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(surplusLimits2[0].amount, 1e18);
        assertEq(surplusLimits2[1].currency, uint32(uint160(_someToken)));
        assertEq(surplusLimits2[1].amount, 2e18);
    }

    function test_GivenTheyAreSpecifiedForASpecificTerminal() external whenAProjectHasSpecifiedSurplusAllowances {
        // it will return them

        JBCurrencyAmount[] memory surplusLimits =
            _fundAccess.surplusAllowancesOf(_projectId, block.timestamp, _terminal2, _someToken);

        assertEq(surplusLimits[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(surplusLimits[0].amount, 1e18);
    }

    function test_GivenTheyAreSpecifiedForASpecificToken() external whenAProjectHasSpecifiedSurplusAllowances {
        // it will return them

        JBCurrencyAmount[] memory surplusLimits =
            _fundAccess.surplusAllowancesOf(_projectId, block.timestamp, _terminal, JBConstants.NATIVE_TOKEN);

        assertEq(surplusLimits[0].currency, uint32(uint160(JBConstants.NATIVE_TOKEN)));
        assertEq(surplusLimits[0].amount, 1e18);
    }
}
