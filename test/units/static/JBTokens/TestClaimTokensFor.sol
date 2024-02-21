// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestClaimTokensFor_Local is JBTokensSetup {

    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsController() {
        _;
    }

    function test_GivenTokenAddressEQZero() external whenCallerIsController {
        // it will revert TOKEN_NOT_FOUND
    }

    function test_GivenCreditBalanceOfGTCallingAmount() external whenCallerIsController {
        // it will revert INSUFFICIENT_CREDITS
    }

    function test_GivenHappyPath() external whenCallerIsController {
        // it will mint to the beneficiary and emit ClaimTokens
    }

    function test_WhenCallerIsNotController() external {
        // it will revert CONTROLLER_UNAUTHORIZED
    }
}
