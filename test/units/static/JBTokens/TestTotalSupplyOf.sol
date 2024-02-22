// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestTotalSupplyOf_Local is JBTokensSetup {
    function setUp() public {
        super.tokensSetup();
    }

    function test_WhenAProjectsTokenDNEQZeroAddress() external {
        // it will return totalCreditSupplyOf plus token total supply
    }

    function test_WhenAProjectsTokenEQZeroAddress() external {
        // it will return zero
    }
}
