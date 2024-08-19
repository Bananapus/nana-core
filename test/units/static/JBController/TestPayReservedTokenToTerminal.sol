// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestExecutePayReservedTokenToTerminal_Local is JBControllerSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    IJBTerminal _terminal = IJBTerminal(makeAddr("someTerminal"));
    IJBToken _token = IJBToken(makeAddr("someToken"));
    address _bene = makeAddr("beneficiary");

    function setUp() public {
        super.controllerSetup();
    }

    function test_WhenCallerIsNotItself() external {
        // it will revert
        vm.expectRevert();
        JBController(address(_controller)).executePayReservedTokenToTerminal(
            _terminal, _projectId, _token, _defaultAmount, _bene, ""
        );
    }

    modifier whenCallerIsItself() {
        // put code at token address for OZ Address check
        vm.etch(address(_token), abi.encode(1));

        vm.prank(address(_controller));
        _;
    }

    function test_GivenAllowanceEQZeroAfterPay() external whenCallerIsItself {
        // it will not revert

        // mock pay call to some terminal
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.pay, (_projectId, address(_token), _defaultAmount, _bene, 0, "", "")),
            abi.encode(0)
        );

        // mock the allowance assertion
        mockExpect(
            address(_token), abi.encodeCall(IERC20.allowance, (address(_controller), address(_terminal))), abi.encode(0)
        );

        JBController(address(_controller)).executePayReservedTokenToTerminal(
            _terminal, _projectId, _token, _defaultAmount, _bene, ""
        );
    }

    function test_GivenAllowanceDNEQZeroAfterPay() external whenCallerIsItself {
        // it will revert

        // mock pay call to some terminal
        mockExpect(
            address(_terminal),
            abi.encodeCall(IJBTerminal.pay, (_projectId, address(_token), _defaultAmount, _bene, 0, "", "")),
            abi.encode(0)
        );

        // mock the allowance assertion
        mockExpect(
            address(_token), abi.encodeCall(IERC20.allowance, (address(_controller), address(_terminal))), abi.encode(1)
        );

        vm.expectRevert();
        JBController(address(_controller)).executePayReservedTokenToTerminal(
            _terminal, _projectId, _token, _defaultAmount, _bene, ""
        );
    }
}
