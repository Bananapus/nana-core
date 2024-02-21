// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestBurnFrom_Local is JBTokensSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    
    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsController() {
        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory),
            abi.encodeCall(IJBDirectory.controllerOf, (_projectId)),
            abi.encode(address(this))
        );

        _;
    }

    function test_GivenTheCallingAmountGTTokenbalancePlusCreditbalanceOfHolder() external whenCallerIsController {
        // it will revert INSUFFICIENT_FUNDS

        vm.expectRevert(abi.encodeWithSignature("INSUFFICIENT_FUNDS()"));
        _tokens.burnFrom(address(this), _projectId, _defaultAmount);
    }

    function test_GivenThereIsACreditBalance() external whenCallerIsController {
        // it will subtract credits from creditBalanceOf and totalCreditSupplyOf

        // Find the storage slot to set credit balance
        bytes32 creditBalanceOfSlot = keccak256(abi.encode(address(this), uint256(3)));
        bytes32 slot = keccak256(abi.encode(_projectId, uint256(creditBalanceOfSlot)));

        // Set storage
        vm.store(address(_tokens), slot, bytes32(_defaultAmount));
        
        // Ensure it is correctly set
        uint256 _creditBalance = _tokens.creditBalanceOf(address(this), _projectId);
        assertEq(_defaultAmount, _creditBalance);

        // Find the storage slot to set totalCreditSupplyOf
        bytes32 totalCreditSlot = keccak256(abi.encode(_projectId, uint256(2)));
        // Set storage
        vm.store(address(_tokens), totalCreditSlot, bytes32(_defaultAmount));

        // Ensure it is correctly set
        uint256 _totalCreditSupply = _tokens.totalCreditSupplyOf(_projectId);
        assertEq(_defaultAmount, _totalCreditSupply);

        _tokens.burnFrom(address(this), _projectId, _defaultAmount);

        // Ensure amount is zeroed now
        uint256 _totalCreditSupplyAfter = _tokens.totalCreditSupplyOf(_projectId);
        assertEq(0, _totalCreditSupplyAfter);

        // Ensure it is correctly set
        uint256 _creditBalanceAfter = _tokens.creditBalanceOf(address(this), _projectId);
        assertEq(0, _creditBalanceAfter);
    }

    /* function test_GivenThereIsErc20TokenBalance() external whenCallerIsController {
        // it will burn tokens
    }

    function test_WhenCallerDNEQController() external {
        // it will revert CONTROLLER_UNAUTHORIZED
    } */
}
