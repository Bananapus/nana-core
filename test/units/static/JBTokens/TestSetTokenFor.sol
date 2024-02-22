// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestSetTokenFor_Local is JBTokensSetup {
    function setUp() public {
        super.tokensSetup();
    }

    function test_WhenTokenIsTheZeroAddress() external {
        // it will revert EMPTY_TOKEN
    }

    function test_WhenATokenIsAlreadySet() external {
        // it will revert TOKEN_ALREADY_SET
    }

    function test_WhenATokenIsAssociatedWithAnotherProject() external {
        // it will revert TOKEN_ALREADY_SET
    }

    function test_WhenATokensDecimalsDNEQ18() external {
        // it will revert TOKENS_MUST_HAVE_18_DECIMALS
    }

    function test_WhenHappyPath() external {
        // it will set token states and emit SetToken
    }
}
