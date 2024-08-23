// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestMintFor_Local is JBTokensSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;
    uint256 _totalSupply = 1e19;
    uint256 _overflowedSupply = uint256(type(uint208).max) + 1;
    address _holder = address(this);

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));

    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsControllerOfProject() {
        // mock call to JBDirectory controllerOf
        mockExpect(
            address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(this))
        );

        _;
    }

    function test_GivenTokenOfTheProjectEQZeroAddress() external whenCallerIsControllerOfProject {
        // it will add tokens to credit balances and total credit supply

        // Find the storage slot to set token
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(0)))));

        _tokens.mintFor(_holder, _projectId, _defaultAmount);

        // Ensure credit supply increase
        uint256 _totalCreditSupplyAfter = _tokens.totalCreditSupplyOf(_projectId);
        assertEq(_defaultAmount, _totalCreditSupplyAfter);

        // Ensure credit balance increase
        uint256 _creditBalanceAfter = _tokens.creditBalanceOf(address(this), _projectId);
        assertEq(_defaultAmount, _creditBalanceAfter);
    }

    function test_GivenTokenDNEQZeroAddress() external whenCallerIsControllerOfProject {
        // it will call token mint

        // Find the storage slot to set token
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        // mock call to token mint()
        mockExpect(address(_token), abi.encodeCall(IJBToken.mint, (_holder, _defaultAmount)), "");

        // mock call to token totalSupply()
        mockExpect(address(_token), abi.encodeCall(IJBToken.totalSupply, ()), abi.encode(_totalSupply));

        _tokens.mintFor(_holder, _projectId, _defaultAmount);
    }

    function test_GivenTotalSupplyAfterMintOrCreditsGTUint208Max() external whenCallerIsControllerOfProject {
        // it will revert OVERFLOW_ALERT

        // Find the storage slot to set token
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        // mock call to token mint()
        mockExpect(address(_token), abi.encodeCall(IJBToken.mint, (_holder, _defaultAmount)), "");

        // mock call to token totalSupply()
        mockExpect(address(_token), abi.encodeCall(IJBToken.totalSupply, ()), abi.encode(_overflowedSupply));

        vm.expectRevert(
            abi.encodeWithSelector(JBTokens.JBTokens_OverflowAlert.selector, _overflowedSupply, type(uint208).max)
        );
        _tokens.mintFor(_holder, _projectId, _defaultAmount);
    }

    function test_WhenCallerIsNotController() external {
        // it will revert CONTROLLER_UNAUTHORIZED

        // mock call to JBDirectory controllerOf
        mockExpect(address(directory), abi.encodeCall(IJBDirectory.controllerOf, (_projectId)), abi.encode(address(0)));

        vm.expectRevert(JBControlled.JBControlled_ControllerUnauthorized.selector);
        _tokens.mintFor(_holder, _projectId, _defaultAmount);
    }
}
