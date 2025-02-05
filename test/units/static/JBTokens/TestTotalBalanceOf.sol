// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestTotalBalanceOf_Local is JBTokensSetup {
    address _holder = address(this);
    uint256 _projectId = 1;
    uint256 _creditBalance = 1e18;
    uint256 _tokenBalance = 2e18;

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));

    function setUp() public {
        super.tokensSetup();
    }

    function test_WhenAProjectsTokenDNEQZeroAddress() external {
        // it will return creditBalanceOf plus token balance of holder

        // Find the storage slot to set credit balance
        bytes32 creditBalanceOfSlot = keccak256(abi.encode(address(this), uint256(0)));
        bytes32 slot = keccak256(abi.encode(_projectId, uint256(creditBalanceOfSlot)));

        // Set storage
        vm.store(address(_tokens), slot, bytes32(_creditBalance));

        // Find the storage slot to set token
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(2)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        // mock call to token balanceOf
        mockExpect(address(_token), abi.encodeCall(IJBToken.balanceOf, (_holder)), abi.encode(_tokenBalance));

        uint256 totalBalance = _tokens.totalBalanceOf(_holder, _projectId);

        // Ensure correct balance
        assertEq(totalBalance, _tokenBalance + _creditBalance);
    }

    function test_WhenAProjectsTokenEQZeroAddressAndCreditBalanceEQZero() external view {
        // it will return zero

        uint256 totalBalance = _tokens.totalBalanceOf(_holder, _projectId);
        assertEq(totalBalance, 0);
    }

    function test_WhenThereIsOnlyCreditBalance() external {
        // it will return only the credit balance

        // Find the storage slot to set credit balance
        bytes32 creditBalanceOfSlot = keccak256(abi.encode(address(this), uint256(0)));
        bytes32 slot = keccak256(abi.encode(_projectId, uint256(creditBalanceOfSlot)));

        // Set storage
        vm.store(address(_tokens), slot, bytes32(_creditBalance));

        uint256 totalBalance = _tokens.totalBalanceOf(_holder, _projectId);
        assertEq(totalBalance, _creditBalance);
    }
}
