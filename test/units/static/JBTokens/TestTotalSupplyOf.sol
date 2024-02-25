// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestTotalSupplyOf_Local is JBTokensSetup {
    uint256 _projectId = 1;
    uint256 _defaultAmount = 1e18;

    // Mocks
    IJBToken _token = IJBToken(makeAddr("token"));

    function setUp() public {
        super.tokensSetup();
    }

    function test_WhenAProjectsTokenDNEQZeroAddress() external {
        // it will return totalCreditSupplyOf plus token total supply

        // Find the storage slot to set totalCreditSupplyOf
        bytes32 totalCreditSlot = keccak256(abi.encode(_projectId, uint256(2)));
        // Set storage
        vm.store(address(_tokens), totalCreditSlot, bytes32(_defaultAmount));

        uint256 supply = _tokens.totalSupplyOf(_projectId);
        assertEq(supply, _defaultAmount);
    }

    function test_WhenATokenIsConfigured() external {
        // it will return totalCreditSupply + total token supply

        // Find the storage slot to set totalCreditSupplyOf
        bytes32 totalCreditSlot = keccak256(abi.encode(_projectId, uint256(2)));
        // Set storage
        vm.store(address(_tokens), totalCreditSlot, bytes32(_defaultAmount));

        // Find the storage slot to set totalCreditSupplyOf
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(0)));
        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        // mock call to token totalSupply()
        mockExpect(address(_token), abi.encodeCall(IJBToken.totalSupply, ()), abi.encode(_defaultAmount));

        uint256 supply = _tokens.totalSupplyOf(_projectId);
        assertEq(supply, _defaultAmount * 2);
    }

    function test_WhenAProjectsTokenEQZeroAddressAndNoCreditSupply() external {
        // it will return zero

        uint256 zeroSupply = _tokens.totalSupplyOf(_projectId);
        assertEq(zeroSupply, 0);
    }
}
