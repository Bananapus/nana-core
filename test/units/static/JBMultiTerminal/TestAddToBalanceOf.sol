// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMultiTerminalSetup} from "./JBMultiTerminalSetup.sol";

contract TestAddToBalanceOf_Local is JBMultiTerminalSetup {
    function setUp() public {
        super.multiTerminalSetup();
    }

    modifier whenShouldReturnHeldFeesEqTrue() {
        _;
    }

    function test_GivenReturnAmountIsZero() external whenShouldReturnHeldFeesEqTrue {
        // it will set heldFeesOf project to zero
    }

    function test_GivenReturnAmountIsNon_zeroAndLeftoverAmountGTEQAmountFromFee()
        external
        whenShouldReturnHeldFeesEqTrue
    {
        // it will return feeAmountIn
    }

    function test_GivenReturnAmountIsNon_zeroAndLeftoverAmountLTAmountFromFee()
        external
        whenShouldReturnHeldFeesEqTrue
    {
        // it will set heldFeesOf return feeAmountFrom and set leftoverAmount to zero
    }

    function test_WhenShouldReturnHeldFeesEqFalse() external {
        // it will call terminalstore recordAddedBalanceFor and emit AddToBalance
    }

    function test_WhenTheProjectDNHAccountingContextForTheToken() external {
        // it will revert TOKEN_NOT_ACCEPTED
    }

    function test_WhenTheTerminalsTokenEqNativeToken() external {
        // it will use msg.value
    }

    function test_WhenTheTerminalsTokenEqNativeTokenAndMsgvalueEqZero() external {
        // it will revert NO_MSG_VALUE_ALLOWED
    }

    function test_WhenTheTerminalIsCallingItself() external {
        // it will not transfer
    }

    modifier whenPayMetadataContainsPermitData() {
        _;
    }

    function test_GivenThePermitAllowanceLtAmount() external whenPayMetadataContainsPermitData {
        // it will revert PERMIT_ALLOWANCE_NOT_ENOUGH
    }

    function test_GivenPermitAllowanceIsGood() external whenPayMetadataContainsPermitData {
        // it will set permit allowance to spend tokens for user via permit2
    }
}
