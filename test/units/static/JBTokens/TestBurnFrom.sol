// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBTokensSetup} from "./JBTokensSetup.sol";

contract TestBurnFrom_Local is JBTokensSetup {
    
    function setUp() public {
        super.tokensSetup();
    }

    modifier whenCallerIsController() {
        _;
    }

    function test_GivenTheCallingAmountGTTokenbalancePlusCreditbalanceOfHolder() external whenCallerIsController {
        // it will revert INSUFFICIENT_FUNDS
    }

    function test_GivenThereIsACreditBalance() external whenCallerIsController {
        // it will subtract credits from creditBalanceOf and totalCreditSupplyOf
    }

    function test_GivenThereIsErc20TokenBalance() external whenCallerIsController {
        // it will burn tokens
    }

    function test_WhenCallerDNEQController() external {
        // it will revert CONTROLLER_UNAUTHORIZED
    }
}
