// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBFeelessSetup} from "./JBFeelessSetup.sol";

contract TestSetFeelessAddress_Local is JBFeelessSetup {
    address _feeLess = makeAddr("something");

    function setUp() public {
        super.feelessAddressesSetup();
    }

    function test_WhenCallerIsOwner() external {
        // it should set isFeeless and emit SetFeelessAddress
        vm.expectEmit();
        emit IJBFeelessAddresses.SetFeelessAddress(_feeLess, true, address(_owner));

        vm.prank(_owner);
        _feelessAddresses.setFeelessAddress(_feeLess, true);

        bool result = _feelessAddresses.isFeeless(_feeLess);
        assertEq(result, true);
    }

    function test_RevertWhen_CallerIsNotOwner() external {
        // it should revert
        _feelessAddresses.setFeelessAddress(_feeLess, true);
    }
}
