// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFundAccessSetup} from "./JBFundAccessSetup.sol";

contract TestSurplusAllowanceOf_Local is JBFundAccessSetup {
    uint256 _projectId = 1;
    address _terminal = address(1);

    function setUp() public {
        super.fundAccessSetup();
    }

    modifier whenCallerIsControllerOfProject() {
        bytes memory _controllerCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _return = abi.encode(address(this));

        mockExpect(address(directory), _controllerCall, _return);
        _;
    }

    function test_WhenAProjectHasTheSpecificSurplusConfigured() external whenCallerIsControllerOfProject {
        // it will return uint256 surplusAllowance

        // Fund Access config
        JBFundAccessLimitGroup[] memory _fundAccessLimitGroup = new JBFundAccessLimitGroup[](2);
        {
            // Specify a payout limit.
            JBCurrencyAmount[] memory _payoutLimits = new JBCurrencyAmount[](0);

            // Specify a surplus allowance.
            JBCurrencyAmount[] memory _surplusAllowances = new JBCurrencyAmount[](1);
            _surplusAllowances[0] =
                JBCurrencyAmount({amount: 1e18, currency: uint32(uint160(JBConstants.NATIVE_TOKEN))});

            _fundAccessLimitGroup[0] = JBFundAccessLimitGroup({
                terminal: _terminal,
                token: JBConstants.NATIVE_TOKEN,
                payoutLimits: _payoutLimits,
                surplusAllowances: _surplusAllowances
            });
        }

        _fundAccess.setFundAccessLimitsFor(_projectId, block.timestamp, _fundAccessLimitGroup);

        uint256 _returned = _fundAccess.surplusAllowanceOf(
            _projectId, block.timestamp, _terminal, JBConstants.NATIVE_TOKEN, uint32(uint160(JBConstants.NATIVE_TOKEN))
        );
        assertEq(_returned, 1e18);
    }

    function test_WhenItDoesntHaveTheSpecificSurplusConfigured() external view {
        // it will return 0

        uint256 _returned = _fundAccess.surplusAllowanceOf(
            _projectId, block.timestamp, _terminal, JBConstants.NATIVE_TOKEN, uint32(uint160(JBConstants.NATIVE_TOKEN))
        );
        assertEq(_returned, 0);
    }
}
