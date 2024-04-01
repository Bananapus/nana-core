// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBProjectsSetup} from "./JBProjectsSetup.sol";

contract TestTokenURI_Local is JBProjectsSetup {
    using stdStorage for StdStorage;

    IJBTokenUriResolver _resolver = IJBTokenUriResolver(makeAddr("uri"));

    function setUp() public {
        super.projectsSetup();
    }

    function test_WhenTheresNoResolver() external {
        // it will return empty string
        string memory uri = IERC721Metadata(address(_projects)).tokenURI(0);

        assertEq(bytes(uri), "");
    }

    function test_WhenTheresAResolver() external {
        // it will return the resolved URI

        // set tokenUriResolver
        stdstore.target(address(_projects)).sig("tokenUriResolver()").checked_write(address(_resolver));

        // mock call to mock resolver
        bytes memory resolverCall = abi.encodeCall(IJBTokenUriResolver.getUri, (0));
        bytes memory returned = abi.encode("JUICAY");

        mockExpect(address(_resolver), resolverCall, returned);

        string memory uri = IERC721Metadata(address(_projects)).tokenURI(0);
        assertEq(bytes(uri), bytes("JUICAY"));
    }
}
