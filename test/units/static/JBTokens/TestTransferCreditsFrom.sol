// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestTransferCreditsFrom_Local is JBTokensSetup {

    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsController() {
        _;
    }

    function test_GivenRecipientEQZeroAddress() external whenCallerIsController {
        // it will revert RECIPIENT_ZERO_ADDRESS
    }

    function test_GivenCallingAmountGTCreditBalance() external whenCallerIsController {
        // it will revert INSUFFICIENT_CREDITS
    }

    function test_GivenHappyPath() external whenCallerIsController {
        // it will subtract creditBalanceOf from holder to recipient and emit TransferCredits
    }
}
