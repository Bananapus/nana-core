// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBControllerSetup} from "./JBControllerSetup.sol";

contract TestReceiveMigrationFrom_Local is JBTest, JBControllerSetup, IJBProjectMetadataRegistry {
    // avoid compiler warning
    function setMetadataOf(uint256 projectId, string calldata metadata) external {}

    function metadataOf(uint256) public pure returns (string memory) {
        return "Juicay";
    }

    function setUp() public {
        super.controllerSetup();
    }

    modifier whenCallerSupportsTheCorrectInterface() {
        bytes memory _encodedCall =
            abi.encodeCall(IERC165.supportsInterface, (type(IJBProjectMetadataRegistry).interfaceId));
        bytes memory _willReturn = abi.encode(true);

        mockExpect(address(this), _encodedCall, _willReturn);
        _;
    }

    modifier whenCallerIsController() {
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(this));

        mockExpect(address(directory), _encodedCall, _willReturn);
        _;
    }

    modifier whenCallerIsNotController() {
        bytes memory _encodedCall = abi.encodeCall(IJBDirectory.controllerOf, (1));
        bytes memory _willReturn = abi.encode(address(1));

        mockExpect(address(directory), _encodedCall, _willReturn);
        _;
    }

    function test_GivenThatTheCallerIsNotControllerOfProjectId()
        external
        whenCallerSupportsTheCorrectInterface
        whenCallerIsNotController
    {
        // it will not set metadata
        bytes32 beforeSet = keccak256(abi.encodePacked(_controller.metadataOf(1)));

        IJBMigratable(address(_controller)).receiveMigrationFrom(IERC165(address(this)), 1);

        bytes32 afterSet = keccak256(abi.encodePacked(_controller.metadataOf(1)));

        bool isEq = beforeSet == afterSet;
        bool isJuicy = afterSet == keccak256(abi.encodePacked("Juicay"));

        assertEq(isEq, true);
        assertEq(isJuicy, false);
    }

    function test_GivenThatTheCallerIsAlsoControllerOfProjectId()
        external
        whenCallerSupportsTheCorrectInterface
        whenCallerIsController
    {
        // it should set metadata
        bytes32 beforeSet = keccak256(abi.encodePacked(_controller.metadataOf(1)));

        IJBMigratable(address(_controller)).receiveMigrationFrom(IERC165(address(this)), 1);

        bytes32 afterSet = keccak256(abi.encodePacked(_controller.metadataOf(1)));

        bool isEq = beforeSet == afterSet;
        bool isJuicy = afterSet == keccak256(abi.encodePacked("Juicay"));

        assertEq(isEq, false);
        assertEq(isJuicy, true);
    }
}
