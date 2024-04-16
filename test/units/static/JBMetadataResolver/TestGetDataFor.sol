// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";
import {JBMetadataResolver} from "../../../../src/libraries/JBMetadataResolver.sol";

contract TestGetDataFor_Local is JBTest {
    bytes4 _id1 = bytes4(0x10101010);
    bytes4 _id2 = bytes4(0x20202020);

    function setUp() external {}

    function test_WhenMetadataLengthLTEQMIN_METADATA_LENGTH() external {
        // it will return false and empty bytes

        // malformed data only contains the padding intended for the protocol
        bytes memory _malformed = abi.encodePacked(bytes32(uint256(type(uint256).max)));

        (bool _found, bytes memory _data) = JBMetadataResolver.getDataFor(_id1, _malformed);

        // check
        assertEq(_found, false);
        assertEq("", _data);
    }

    modifier whenMetadataLengthGTMIN_METADATA_LENGTH() {
        _;
    }

    function test_GivenIdIsFound() external whenMetadataLengthGTMIN_METADATA_LENGTH {
        // it will return found EQ true and targetData

        uint256 _data1 = 10_000_000;
        bytes memory _data2 = new bytes(100);

        // malformed data only contains the padding intended for the protocol
        bytes memory _metadata = abi.encodePacked(
            // -- offset 0 --
            bytes32(uint256(type(uint256).max)), // First 32B reserved
            // -- offset 1 --
            _id1, // First id
            uint8(2), // First data offset == 2
            _id2, // Second id == _id
            uint8(3), // Second data offset == 3
            bytes22(0), // Rest of the word is 0-padded
            // -- offset 2 --
            _data1, // First data
            // -- offset 3 --
            _data2 // Second data
        );

        (bool _found, bytes memory _returnedData) = JBMetadataResolver.getDataFor(_id1, _metadata);

        // check
        assertEq(_found, true);
        assertEq(abi.decode(_returnedData, (uint256)), _data1);
    }

    function test_GivenIdIsNotFound() external whenMetadataLengthGTMIN_METADATA_LENGTH {
        // it will return found EQ false and empty bytes targetData

        uint256 _data1 = 10_000_000;
        bytes memory _data2 = new bytes(100);

        // malformed data only contains the padding intended for the protocol
        bytes memory _metadata = abi.encodePacked(
            // -- offset 0 --
            bytes32(uint256(type(uint256).max)), // First 32B reserved
            // -- offset 1 --
            _id1, // First id
            uint8(2), // First data offset == 2
            _id2, // Second id == _id
            uint8(3), // Second data offset == 3
            bytes22(0), // Rest of the word is 0-padded
            // -- offset 2 --
            _data1, // First data
            // -- offset 3 --
            _data2 // Second data
        );

        bytes4 _invalidId = bytes4(0x40404040);

        (bool _found, bytes memory _returnedData) = JBMetadataResolver.getDataFor(_invalidId, _metadata);

        // check
        assertEq(_found, false);
        assertEq("", _returnedData);
    }
}
