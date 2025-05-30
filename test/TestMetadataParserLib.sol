// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "./helpers/TestBaseWorkflow.sol";

/**
 * @notice Test the `JBDelegateMetadata` library and helper contract.
 *
 * @dev    These are a mixed collection of unit and integration tests.
 */
contract JBDelegateMetadataLib_Test_Local is Test {
    MetadataResolverHelper parser;

    /**
     * @notice Deploy the helper contract.
     *
     * @dev    Helper inherits the lib and add `createMetadata`.
     */
    function setUp() external {
        parser = new MetadataResolverHelper();
    }

    /**
     * @notice Test the parsing of arbitrary metadata.
     */
    function test_parse() external view {
        bytes4 _id1 = bytes4(0x11111111);
        bytes4 _id2 = bytes4(0x33333333);

        uint256 _data1 = 69_696_969;
        bytes memory _data2 = new bytes(50);

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

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(_id2, _metadata);
        assertEq(_dataParsed, _data2);
        assertTrue(_found);

        (_found, _dataParsed) = parser.getDataFor(_id1, _metadata);
        assertEq(abi.decode(_dataParsed, (uint256)), _data1);
        assertTrue(_found);
    }

    /**
     * @notice Test creating and parsing bytes only metadata.
     */
    function test_createAndParse_bytes() external view {
        bytes4[] memory _ids = new bytes4[](10);
        bytes[] memory _datas = new bytes[](10);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(
                bytes1(uint8(_i + 1)), uint32(69), bytes2(uint16(_i + 69)), bytes32(uint256(type(uint256).max))
            );
        }

        bytes memory _metadata = parser.createMetadata(_ids, _datas);

        for (uint256 _i; _i < _ids.length; _i++) {
            (bool _found, bytes memory _dataParsed) = parser.getDataFor(_ids[_i], _metadata);
            (bytes1 _a, uint32 _deadBeef, bytes2 _c, bytes32 _d) =
                abi.decode(_dataParsed, (bytes1, uint32, bytes2, bytes32));

            assertTrue(_found);

            assertEq(uint8(_a), _i + 1);
            assertEq(uint256(_deadBeef), uint32(69));
            assertEq(uint16(_c), _i + 69);
            assertEq(_d, bytes32(uint256(type(uint256).max)));
        }
    }

    /**
     * @notice Test creating and parsing `uint`-only metadata.
     */
    function test_createAndParse_uint(uint256 _numberOfIds) external {
        // Maximum 219 hooks with 1 word data (offset overflow if more).
        _numberOfIds = bound(_numberOfIds, 1, 220);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfIds);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(type(uint256).max - _i);
        }

        if (_numberOfIds == 220) vm.expectRevert(JBMetadataResolver.JBMetadataResolver_MetadataTooLong.selector);
        bytes memory _metadata = parser.createMetadata(_ids, _datas);
        if (_numberOfIds < 220) {
            for (uint256 _i; _i < _ids.length; _i++) {
                (bool _found, bytes memory _dataParsed) = parser.getDataFor(_ids[_i], _metadata);
                uint256 _data = abi.decode(_dataParsed, (uint256));

                assertTrue(_found);
                assertEq(_data, type(uint256).max - _i);
            }
        }
    }

    /**
     * @notice Test creating and parsing metadata of varying length.
     */
    function test_createAndParse_mixed(uint256 _numberOfIds) external view {
        _numberOfIds = bound(_numberOfIds, 1, 15);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfIds);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(69 << _i * 20);
        }

        bytes memory _metadata = parser.createMetadata(_ids, _datas);

        for (uint256 _i; _i < _ids.length; _i++) {
            (bool _found, bytes memory _dataParsed) = parser.getDataFor(_ids[_i], _metadata);
            uint256 _data = abi.decode(_dataParsed, (uint256));

            assertTrue(_found);
            assertEq(_data, 69 << _i * 20);
        }
    }

    /**
     * @notice Test if `createMetadata` reverts when the offset would overflow.
     */
    function test_createRevertIfOffsetTooBig(uint256 _numberOfIds) external {
        // Max 1000 for evm memory limit
        _numberOfIds = bound(_numberOfIds, 221, 1000);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfIds);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(type(uint256).max - _i);
        }

        vm.expectRevert(JBMetadataResolver.JBMetadataResolver_MetadataTooLong.selector);
        parser.createMetadata(_ids, _datas);
    }

    /**
     * @notice Test adding `uint` to an `uint` metadata.
     */
    function test_addToMetadata_uint(uint256 _numberOfIds) external view {
        _numberOfIds = bound(_numberOfIds, 1, 219);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfIds);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(type(uint256).max - _i);
        }

        bytes memory _metadata = parser.createMetadata(_ids, _datas);

        bytes memory _modifiedMetadata =
            parser.addDataToMetadata(_metadata, bytes4(uint32(type(uint32).max)), abi.encode(123_456));

        // Check
        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _modifiedMetadata);
        uint256 _data = abi.decode(_dataParsed, (uint256));

        assertTrue(_found);
        assertEq(_data, 123_456);

        for (uint256 _i; _i < _ids.length; _i++) {
            (_found, _dataParsed) = parser.getDataFor(_ids[_i], _modifiedMetadata);
            _data = abi.decode(_dataParsed, (uint256));

            assertTrue(_found);
            assertEq(_data, type(uint256).max - _i);
        }
    }

    /**
     * @notice Test adding `bytes` to a `bytes` metadata.
     */
    function test_addToMetadata_bytes() public view {
        bytes4[] memory _ids = new bytes4[](2);
        bytes[] memory _datas = new bytes[](2);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(
                bytes1(uint8(_i + 1)), uint32(69), bytes2(uint16(_i + 69)), bytes32(uint256(type(uint256).max))
            );
        }

        bytes memory _metadata = parser.createMetadata(_ids, _datas);

        bytes memory _modifiedMetadata = parser.addDataToMetadata(
            _metadata,
            bytes4(uint32(type(uint32).max)),
            abi.encode(bytes32(uint256(type(uint256).max)), bytes32(hex"123456"))
        );

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _modifiedMetadata);
        (bytes32 _a, bytes32 _b) = abi.decode(_dataParsed, (bytes32, bytes32));

        assertTrue(_found);
        assertEq(bytes32(uint256(type(uint256).max)), _a);
        assertEq(bytes32(hex"123456"), _b);

        for (uint256 _i; _i < _ids.length; _i++) {
            (_found, _dataParsed) = parser.getDataFor(_ids[_i], _modifiedMetadata);

            (bytes1 _c, uint32 _d, bytes2 _e, bytes32 _f) = abi.decode(_dataParsed, (bytes1, uint32, bytes2, bytes32));

            assertTrue(_found);
            assertEq(uint8(_c), _i + 1);
            assertEq(_d, uint32(69));
            assertEq(uint16(_e), _i + 69);
            assertEq(_f, bytes32(uint256(type(uint256).max)));
        }
    }

    /**
     * @notice Test adding `bytes` to an `uint` metadata.
     */
    function test_addToMetadata_mixed(uint256 _numberOfIds) external view {
        _numberOfIds = bound(_numberOfIds, 1, 100);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfIds);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(_i * 4);
        }

        bytes memory _metadata = parser.createMetadata(_ids, _datas);

        bytes memory _modifiedMetadata = parser.addDataToMetadata(
            _metadata, bytes4(uint32(type(uint32).max)), abi.encode(uint32(69), bytes32(uint256(type(uint256).max)))
        );

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _modifiedMetadata);
        (uint32 _a, bytes32 _b) = abi.decode(_dataParsed, (uint32, bytes32));

        assertTrue(_found);
        assertEq(_a, uint32(69));
        assertEq(_b, bytes32(uint256(type(uint256).max)));

        for (uint256 _i; _i < _ids.length; _i++) {
            (_found, _dataParsed) = parser.getDataFor(_ids[_i], _modifiedMetadata);
            uint256 _data = abi.decode(_dataParsed, (uint256));

            assertTrue(_found);
            assertEq(_data, _i * 4);
        }
    }

    /**
     * @notice Test adding `bytes32` and `uint` to an empty metadata.
     */
    function test_addToMetadata_emptyInitialMetadata() external view {
        bytes memory _metadata;

        bytes memory _modifiedMetadata = parser.addDataToMetadata(
            _metadata, bytes4(uint32(type(uint32).max)), abi.encode(uint32(69), bytes32(uint256(type(uint256).max)))
        );

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _modifiedMetadata);
        (uint32 _a, bytes32 _b) = abi.decode(_dataParsed, (uint32, bytes32));

        assertTrue(_found);
        assertEq(_a, uint32(69));
        assertEq(_b, bytes32(uint256(type(uint256).max)));
    }

    /**
     * @notice Test adding `bytes32` and `uint` to a metadata which contains something in the first bytes32
     */
    function test_addToMetadata_preexistingMetadata(uint256 _reserved) external view {
        bytes memory _metadata = abi.encode(_reserved);

        bytes memory _modifiedMetadata = parser.addDataToMetadata(
            _metadata, bytes4(uint32(type(uint32).max)), abi.encode(uint32(69), bytes32(uint256(type(uint256).max)))
        );

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _modifiedMetadata);
        (uint32 _a, bytes32 _b) = abi.decode(_dataParsed, (uint32, bytes32));

        assertTrue(_found);
        assertEq(_a, uint32(69));
        assertEq(_b, bytes32(uint256(type(uint256).max)));

        assertEq(uint256(bytes32(_modifiedMetadata)), _reserved);
    }

    function test_addToMetadata_invalidExistingTable_reverts() public {
        vm.expectRevert(JBMetadataResolver.JBMetadataResolver_MetadataTooShort.selector);

        // Preexisting metadata: 32B + 4B
        parser.addDataToMetadata(
            abi.encodePacked(bytes32(uint256(type(uint256).max)), bytes4(uint32(type(uint32).max))),
            bytes4(uint32(type(uint32).max)),
            bytes("12345678901234567890123456789012345678901234567890123456789012345678901234567890")
        );
    }

    function test_addToMetadata_shortDataToAdd_reverts() public {
        vm.expectRevert(JBMetadataResolver.JBMetadataResolver_DataNotPadded.selector);

        // Preexisting metadata: 32B + 4B
        parser.addDataToMetadata(
            abi.encodePacked(bytes32(uint256(type(uint256).max)), bytes8(uint64(type(uint64).max))),
            bytes4(uint32(type(uint32).max)),
            bytes("1234")
        );
    }

    /**
     * @notice Test behaviour if the ID is not found in the lookup table.
     */
    function test_idNotFound(uint256 _numberOfIds) public view {
        _numberOfIds = bound(_numberOfIds, 1, 100);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfIds);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
            _datas[_i] = abi.encode(_i * 4);
        }

        bytes memory _metadata = parser.createMetadata(_ids, _datas);

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _metadata);

        assertFalse(_found);
        assertEq(_dataParsed, "");
    }

    /**
     * @notice Test behaviour if the metadata is empty or less than one ID long.
     */
    function test_emptyMetadata(uint256 _length) public view {
        _length = bound(_length, 0, 37);

        bytes memory _metadata;

        // Fill with hex `F`.
        _metadata = abi.encodePacked(bytes32(uint256(type(uint256).max)), bytes32(uint256(type(uint256).max)));

        // Downsize to the length.
        assembly {
            mstore(_metadata, _length)
        }

        (bool _found, bytes memory _dataParsed) = parser.getDataFor(bytes4(uint32(type(uint32).max)), _metadata);

        assertFalse(_found);
        assertEq(_dataParsed, "");
    }

    function test_differentSizeIdAndMetadataArray_reverts(uint256 _numberOfIds, uint256 _numberOfMetadatas) public {
        _numberOfIds = bound(_numberOfIds, 1, 100);
        _numberOfMetadatas = bound(_numberOfMetadatas, 1, 100);

        vm.assume(_numberOfIds != _numberOfMetadatas);

        bytes4[] memory _ids = new bytes4[](_numberOfIds);
        bytes[] memory _datas = new bytes[](_numberOfMetadatas);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));
        }

        for (uint256 _i; _i < _datas.length; _i++) {
            _datas[_i] = abi.encode(_i * 4);
        }

        // Below should revert.
        vm.expectRevert(JBMetadataResolver.JBMetadataResolver_LengthMismatch.selector);
        parser.createMetadata(_ids, _datas);
    }

    /**
     * @notice Test creating and parsing metadata of incorrect length.
     */
    function test_create__unpadded() external {
        bytes4[] memory _ids = new bytes4[](1);
        bytes[] memory _datas = new bytes[](1);

        uint8 something = uint8(1);
        bytes memory shortData = abi.encodePacked(something);

        _ids[0] = bytes4(uint32(1));
        _datas[0] = shortData;

        vm.expectRevert(JBMetadataResolver.JBMetadataResolver_DataNotPadded.selector);
        parser.createMetadata(_ids, _datas);
    }

    /**
     * @notice Test creating and parsing bytes only metadata.
     */
    function test_create_incorrect_data_length() external {
        bytes4[] memory _ids = new bytes4[](10);
        bytes[] memory _datas = new bytes[](10);

        for (uint256 _i; _i < _ids.length; _i++) {
            _ids[_i] = bytes4(uint32(_i + 1 * 1000));

            _datas[_i] = abi.encodePacked(
                bytes1(uint8(_i + 1)), uint32(69), bytes2(uint16(_i + 69)), bytes32(uint256(type(uint256).max))
            );
        }

        // Ensure data length is not multiple of word size and is gt word size.
        assertGt(_datas[0].length, 32);
        assertGt(_datas[0].length % 32, 0);

        // New revert to help integrators.
        vm.expectRevert(JBMetadataResolver.JBMetadataResolver_DataNotPadded.selector);
        parser.createMetadata(_ids, _datas);
    }
}
