// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestMintFor_Local is JBTokensSetup {

    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsControllerOfProject() {
        _;
    }

    function test_GivenTokenOfTheProjectEQZeroAddress() external whenCallerIsControllerOfProject {
        // it will add tokens to credit balances and total credit supply
    }

    function test_GivenTokenDNEQZeroAddress() external whenCallerIsControllerOfProject {
        // it will call token mint
    }

    function test_GivenTotalSupplyAfterMintOrCreditsGTUint208Max() external whenCallerIsControllerOfProject {
        // it will revert OVERFLOW_ALERT
    }

    function test_WhenCallerIsNotController() external {
        // it will revert CONTROLLER_UNAUTHORIZED
    }
}
