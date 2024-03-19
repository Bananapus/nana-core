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
        bool result1 = IERC165(address(_feelessAddresses)).supportsInterface(type(IJBFeelessAddresses).interfaceId);
        assertEq(result1, true);

        bool result2 = IERC165(address(_feelessAddresses)).supportsInterface(type(IERC165).interfaceId);
        assertEq(result2, true);
    }

    function test_WhenAskedIfSupportsNonIJBFeelessAddressesOrIERC165() external {
        // it should return false
        bool result1 = IERC165(address(_feelessAddresses)).supportsInterface(0x12345678);
        assertEq(result1, false);

        bool result2 = IERC165(address(_feelessAddresses)).supportsInterface(0x12345679);
        assertEq(result2, false);
    }
}
