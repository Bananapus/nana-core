// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestPayoutLimitOf_Local is JBFundAccessSetup {
    uint256 _projectId = 1;
    uint256 _ruleset = block.timestamp;
    uint224 _payoutLimit = 1e18;
    uint32 _currency = uint32(uint160(JBConstants.NATIVE_TOKEN));
    address _terminal = address(1);
    address _token = JBConstants.NATIVE_TOKEN;

    function setUp() public {
        super.fundAccessSetup();

        // Fund Access config
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](1);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](1);
            _payoutLimits[0] =
                JBCurrencyAmount({amount: _payoutLimit, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](0);

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: address(_terminal),
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        bytes memory _controllerCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _return = abi.encode(address(this));

        mockExpect(address(directory), _controllerCall, _return);

        _fundAccess.setFundAccessLimitsFor(_projectId, _ruleset, _fundAccessLimitGroup);
    }

    function test_WhenTheProjectHasTheSpecificPayoutLimit() external {
        // it will return the uint256 payoutLimit
        uint256 _returnedLimit = _fundAccess.payoutLimitOf(_projectId, _ruleset, _terminal, _token, _currency);
        assertEq(_returnedLimit, _payoutLimit);
    }

    function test_WhenTheProjectDoesntHaveTheSpecificPayoutLimit() external {
        // it will return 0
        uint256 empty = _fundAccess.payoutLimitOf(1, 1, address(1), address(2), 1);
        assertEq(empty, 0);
    }
}
