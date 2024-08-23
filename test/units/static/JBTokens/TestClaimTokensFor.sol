// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestClaimTokensFor_Local is JBTokensSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    address _holder = address(this);
    address _beneficiary = makeAddr("guy");

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));

    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsController() {
        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        _;
    }

    function test_GivenTokenAddressEQZero() external whenCallerIsController {
        // it will revert TOKEN_NOT_FOUND

        // Find the storage slot to set credit balance
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(0)))));

        vm.expectRevert(JBTokens.JBTokens_TokenNotFound.selector);
        _tokens.claimTokensFor(_holder, _projectId, _defaultAmount, _beneficiary);
    }

    function test_GivenCreditBalanceOfGTCallingAmount() external whenCallerIsController {
        // it will revert INSUFFICIENT_CREDITS

        // Find the storage slot to set credit balance
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        vm.expectRevert(abi.encodeWithSelector(JBTokens.JBTokens_InsufficientCredits.selector, _defaultAmount, 0));
        _tokens.claimTokensFor(_holder, _projectId, _defaultAmount, _beneficiary);
    }

    function test_GivenHappyPath() external whenCallerIsController {
        // it will mint to the beneficiary and emit ClaimTokens

        // Find the storage slot to set credit balance
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        // Find the storage slot to set credit balance
        bytes32 creditBalanceOfSlot = keccak256(abi.encode(address(this), uint256(0)));
        bytes32 slot = keccak256(abi.encode(_projectId, uint256(creditBalanceOfSlot)));

        // Set storage
        vm.store(address(_tokens), slot, bytes32(_defaultAmount));

        // Ensure it is correctly set
        uint256 _creditBalance = _tokens.creditBalanceOf(address(this), _projectId);
        assertEq(_defaultAmount, _creditBalance);

        // Find the storage slot to set totalCreditSupplyOf
        bytes32 totalCreditSlot = keccak256(abi.encode(_projectId, uint256(3)));
        // Set storage
        vm.store(address(_tokens), totalCreditSlot, bytes32(_defaultAmount));

        // Ensure it is correctly set
        uint256 _totalCreditSupply = _tokens.totalCreditSupplyOf(_projectId);
        assertEq(_defaultAmount, _totalCreditSupply);

        // mock call to token mint()
        mockExpect(address(_token), abi.encodeCall(IJBToken.mint, (_beneficiary, _defaultAmount)), "");

        _tokens.claimTokensFor(_holder, _projectId, _defaultAmount, _beneficiary);

        // Ensure amount is zeroed now
        uint256 _totalCreditSupplyAfter = _tokens.totalCreditSupplyOf(_projectId);
        assertEq(0, _totalCreditSupplyAfter);

        // Ensure it is correctly set
        uint256 _creditBalanceAfter = _tokens.creditBalanceOf(address(this), _projectId);
        assertEq(0, _creditBalanceAfter);
    }

    function test_WhenCallerIsNotController() external {
        // it will revert CONTROLLER_UNAUTHORIZED

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(0)));

        vm.expectRevert(JBControlled.JBControlled_ControllerUnauthorized.selector);
        _tokens.claimTokensFor(_holder, _projectId, _defaultAmount, _beneficiary);
    }
}
