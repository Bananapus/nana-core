// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFeelessSetup} from "./JBFeelessSetup.sol";

contract TestSupportsInterface_Local is JBFeelessSetup {
    function setUp() public {
        super.feelessAddressesSetup();
    }
    
    function test_WhenItSupportsEitherIJBFeelessAddressesOrIERC165() external {
        // it should return true
    }

    function test_WhenItDoesntSupportEitherIJBFeelessAddressesOrIERC165() external {
        // it should return false
    }
}
