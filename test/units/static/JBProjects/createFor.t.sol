// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBProjectsSetup} from "./JBProjectsSetup.sol";

contract TestCreateFor_Local is JBProjectsSetup {
    function setUp() public {
        super.projectsSetup();
    }

    function test_WhenProjectIdPlusOneIsGtUint256Max() external {
        // it will revert
    }

    modifier whenProjectIdPlusOneIsLtOrEqToUint256Max() {
        _;
    }

    function test_GivenOwnerIsNotAContract() external whenProjectIdPlusOneIsLtOrEqToUint256Max {
        // it will mint and emit Create
    }

    modifier givenOwnerIsAContract() {
        _;
    }

    function test_GivenItIsIERC721Receiver() external whenProjectIdPlusOneIsLtOrEqToUint256Max givenOwnerIsAContract {
        // it will mint and emit Create
    }

    function test_GivenItDoesNotSupportIERC721Receiver()
        external
        whenProjectIdPlusOneIsLtOrEqToUint256Max
        givenOwnerIsAContract
    {
        // it will revert
    }
}
