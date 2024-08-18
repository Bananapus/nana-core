// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestTransferCreditsFrom_Local is JBTokensSetup {
    address _holder = address(this);
    uint256 _projectId = 1;
    address _recipient = makeAddr("guy");
    uint256 _defaultAmount = 1e18;

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

    function test_GivenRecipientEQZeroAddress() external whenCallerIsController {
        // it will revert RECIPIENT_ZERO_ADDRESS

        vm.expectRevert(JBTokens.JBTokens_RecipientZeroAddress.selector);
        _tokens.transferCreditsFrom(_holder, _projectId, address(0), _defaultAmount);
    }

    function test_GivenCallingAmountGTCreditBalance() external whenCallerIsController {
        // it will revert INSUFFICIENT_CREDITS

        vm.expectRevert(JBTokens.JBTokens_InsufficientCredits.selector);
        _tokens.transferCreditsFrom(_holder, _projectId, _recipient, _defaultAmount);
    }

    function test_GivenHappyPath() external whenCallerIsController {
        // it will subtract creditBalanceOf from holder to recipient and emit TransferCredits

        // Find the storage slot to set credit balance
        bytes32 creditBalanceOfSlot = keccak256(abi.encode(_holder, uint256(0)));
        bytes32 slot = keccak256(abi.encode(_projectId, uint256(creditBalanceOfSlot)));

        // Set storage
        vm.store(address(_tokens), slot, bytes32(_defaultAmount));

        // Ensure it is correctly set
        uint256 _creditBalance = _tokens.creditBalanceOf(address(this), _projectId);
        assertEq(_defaultAmount, _creditBalance);

        vm.expectEmit();
        emit IJBTokens.TransferCredits(_holder, _projectId, _recipient, _defaultAmount, _holder);

        _tokens.transferCreditsFrom(_holder, _projectId, _recipient, _defaultAmount);
        uint256 recipientBalance = _tokens.creditBalanceOf(_recipient, _projectId);
        assertEq(recipientBalance, _defaultAmount);
    }
}
