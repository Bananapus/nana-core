// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestSetTokenFor_Local is JBTokensSetup {
    uint256 _projectId = 1;

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

    function test_WhenTokenIsTheZeroAddress() external whenCallerIsControllerOfProject {
        // it will revert EMPTY_TOKEN

        vm.expectRevert(abi.encodeWithSignature("EMPTY_TOKEN()"));
        _tokens.setTokenFor(_projectId, IJBToken(address(0)));
    }

    function test_WhenATokenIsAlreadySet() external whenCallerIsControllerOfProject {
        // it will revert TOKEN_ALREADY_SET

        // Find the storage slot to set token
        bytes32 tokenOfSlot = keccak256(abi.encode(_projectId, uint256(0)));

        // Set storage
        vm.store(address(_tokens), tokenOfSlot, bytes32(uint256(uint160(address(_token)))));

        vm.expectRevert(abi.encodeWithSignature("TOKEN_ALREADY_SET()"));
        _tokens.setTokenFor(_projectId, IJBToken(address(_token)));
    }

    function test_WhenATokenIsAssociatedWithAnotherProject() external whenCallerIsControllerOfProject {
        // it will revert TOKEN_ALREADY_SET

        // Find the storage slot to set token
        bytes32 projectIdOfSlot = keccak256(abi.encode(_token, uint256(1)));

        // Set storage
        vm.store(address(_tokens), projectIdOfSlot, bytes32(uint256(uint160(address(_token)))));

        vm.expectRevert(abi.encodeWithSignature("TOKEN_ALREADY_SET()"));
        _tokens.setTokenFor(_projectId, IJBToken(address(_token)));
    }

    function test_WhenATokensDecimalsDNEQ18() external whenCallerIsControllerOfProject {
        // it will revert TOKENS_MUST_HAVE_18_DECIMALS

        //mock call to token decimals
        mockExpect(address(_token), abi.encodeCall(IJBToken.decimals, ()), abi.encode(6));

        vm.expectRevert(abi.encodeWithSignature("TOKENS_MUST_HAVE_18_DECIMALS()"));
        _tokens.setTokenFor(_projectId, IJBToken(address(_token)));
    }

    function test_WhenHappyPath() external whenCallerIsControllerOfProject {
        // it will set token states and emit SetToken

        //mock call to token decimals
        mockExpect(address(_token), abi.encodeCall(IJBToken.decimals, ()), abi.encode(18));

        vm.expectEmit();
        emit IJBTokens.SetToken(_projectId, _token, address(this));

        _tokens.setTokenFor(_projectId, IJBToken(address(_token)));
    }
}
