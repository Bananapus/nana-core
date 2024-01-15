// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @notice Library to parse and create metadata to store {id: data} entries.
 *
 * @dev    Metadata are built as:
 *         - 32B of reserved space for the protocol
 *         - a lookup table `Id: offset`, defining the offset of the data for a given 4 bytes id.
 *           The offset fits 1 bytes, the ID 4 bytes. This table is padded to 32B.
 *         - the data for each id, padded to 32B each
 *
 *            +-----------------------+ offset: 0
 *            | 32B reserved          |
 *            +-----------------------+ offset: 1 = end of first 32B
 *            |      (ID1,offset1)    |
 *            |      (ID2,offset2)    |
 *            |       0's padding     |
 *            +-----------------------+ offset: offset1 = 1 + number of words taken by the padded table
 *            |       id1 data1       |
 *            | 0's padding           |
 *            +-----------------------+ offset: offset2 = offset1 + number of words taken by the data1
 *            |       id2 data2       |
 *            | 0's padding           |
 *            +-----------------------+
 */
library JBMetadataResolver {
    // The various sizes used in bytes.
    uint256 constant ID_SIZE = 4;
    uint256 constant ID_OFFSET_SIZE = 1;
    uint256 constant WORD_SIZE = 32;

    // The size that an ID takes in the lookup table (Identifier + Offset).
    uint256 constant TOTAL_ID_SIZE = 5; // ID_SIZE + ID_OFFSET_SIZE;

    // The amount of bytes to go forward to get to the offset of the next ID (aka. the end of the offset of the current
    // ID).
    uint256 constant NEXT_ID_OFFSET = 9; // TOTAL_ID_SIZE + ID_SIZE;

    // 1 word (32B) is reserved for the protocol .
    uint256 constant RESERVED_SIZE = 32; // 1 * WORD_SIZE;
    uint256 constant MIN_METADATA_LENGTH = 37; // RESERVED_SIZE + ID_SIZE + ID_OFFSET_SIZE;

    /**
     * @notice Parse the metadata to find the data for a specific ID
     *
     * @dev    Returns false and an empty bytes if no data is found
     *
     * @param  id             The ID to find
     * @param  metadata       The metadata to parse
     *
     * @return found          Whether the {id:data} was found
     * @return targetData The data for the ID (can be empty)
     */
    function getDataFor(bytes4 id, bytes memory metadata) internal pure returns (bool found, bytes memory targetData) {
        // Either no data or empty one with only one selector (32+4+1)
        if (metadata.length <= MIN_METADATA_LENGTH) return (false, "");

        // Get the first data offset - upcast to avoid overflow (same for other offset)
        uint256 firstOffset = uint8(metadata[RESERVED_SIZE + ID_SIZE]);

        // Parse the id's to find id, stop when next offset == 0 or current = first offset
        for (uint256 i = RESERVED_SIZE; metadata[i + ID_SIZE] != bytes1(0) && i < firstOffset * WORD_SIZE;) {
            uint256 currentOffset = uint256(uint8(metadata[i + ID_SIZE]));

            // _id found?
            if (bytes4(_sliceBytes(metadata, i, i + ID_SIZE)) == id) {
                // Are we at the end of the lookup table (either at the start of data's or next offset is 0/in the
                // padding)
                // If not, only return until from this offset to the begining of the next offset
                uint256 end = (i + NEXT_ID_OFFSET >= firstOffset * WORD_SIZE || metadata[i + NEXT_ID_OFFSET] == 0)
                    ? metadata.length
                    : uint256(uint8(metadata[i + NEXT_ID_OFFSET])) * WORD_SIZE;

                return (true, _sliceBytes(metadata, currentOffset * WORD_SIZE, end));
            }
            unchecked {
                i += TOTAL_ID_SIZE;
            }
        }
    }

    /**
     * @notice Add an {id: data} entry to an existing metadata. This is an append-only mechanism.
     *
     * @param originalMetadata The original metadata
     * @param idToAdd          The id to add
     * @param dataToAdd        The data to add
     *
     * @return newMetadata    The new metadata with the entry added
     */
    function addToMetadata(
        bytes memory originalMetadata,
        bytes4 idToAdd,
        bytes memory dataToAdd
    )
        internal
        pure
        returns (bytes memory newMetadata)
    {
        // Get the first data offset - upcast to avoid overflow (same for other offset)...
        uint256 firstOffset = uint8(originalMetadata[RESERVED_SIZE + ID_SIZE]);

        // ...go back to the beginning of the previous word (ie the last word of the table, as it can be padded)
        uint256 lastWordOfTable = firstOffset - 1;

        // The last offset stored in the table and its index
        uint256 lastOffset;

        uint256 lastOffsetIndex;

        // The number of words taken by the last data stored
        uint256 numberOfWordslastData;

        // Iterate to find the last entry of the table, lastOffset - we start from the end as the first value
        // encountered
        // will be the last offset
        for (uint256 i = firstOffset * WORD_SIZE - 1; i > lastWordOfTable * WORD_SIZE - 1; i--) {
            // If the byte is not 0, this is the last offset we're looking for
            if (originalMetadata[i] != 0) {
                lastOffset = uint8(originalMetadata[i]);
                lastOffsetIndex = i;

                // No rounding as this should be padded to 32B
                numberOfWordslastData = (originalMetadata.length - lastOffset * WORD_SIZE) / WORD_SIZE;

                // Copy the reserved word and the table and remove the previous padding
                newMetadata = _sliceBytes(originalMetadata, 0, lastOffsetIndex + 1);

                // Check if the new entry is still fitting in this word
                if (i + TOTAL_ID_SIZE >= firstOffset * WORD_SIZE) {
                    // Increment every offset by 1 (as the table now takes one more word)
                    for (uint256 j = RESERVED_SIZE + ID_SIZE; j < lastOffsetIndex + 1; j += TOTAL_ID_SIZE) {
                        newMetadata[j] = bytes1(uint8(originalMetadata[j]) + 1);
                    }

                    // Increment the last offset so the new offset will be properly set too
                    lastOffset++;
                }

                break;
            }
        }

        // Add the new entry after the last entry of the table, the new offset is the last offset + the number of words
        // taken by the last data
        newMetadata = abi.encodePacked(newMetadata, idToAdd, bytes1(uint8(lastOffset + numberOfWordslastData)));

        // Pad as needed - inlined for gas saving
        uint256 paddedLength =
            newMetadata.length % WORD_SIZE == 0 ? newMetadata.length : (newMetadata.length / WORD_SIZE + 1) * WORD_SIZE;
        assembly {
            mstore(newMetadata, paddedLength)
        }

        // Add existing data at the end
        newMetadata = abi.encodePacked(
            newMetadata, _sliceBytes(originalMetadata, firstOffset * WORD_SIZE, originalMetadata.length)
        );

        // Pad as needed
        paddedLength =
            newMetadata.length % WORD_SIZE == 0 ? newMetadata.length : (newMetadata.length / WORD_SIZE + 1) * WORD_SIZE;
        assembly {
            mstore(newMetadata, paddedLength)
        }

        // Append new data at the end
        newMetadata = abi.encodePacked(newMetadata, dataToAdd);

        // Pad again again as needed
        paddedLength =
            newMetadata.length % WORD_SIZE == 0 ? newMetadata.length : (newMetadata.length / WORD_SIZE + 1) * WORD_SIZE;

        assembly {
            mstore(newMetadata, paddedLength)
        }
    }

    /// @notice Slice bytes from a start index to an end index.
    /// @param data The data being sliced.
    /// @param start The start index to slice at.
    /// @param end The end index to slice at.
    /// @param slicedBytes The sliced bytes.
    function _sliceBytes(
        bytes memory data,
        uint256 start,
        uint256 end
    )
        internal
        pure
        returns (bytes memory slicedBytes)
    {
        slicedBytes = new bytes(end - start);
        for (uint256 i = start; i < end; i++) {
            slicedBytes[i - start] = data[i];
        }
    }
}
