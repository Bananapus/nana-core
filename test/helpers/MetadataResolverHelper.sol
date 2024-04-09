// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBMetadataResolver} from "../../src/libraries/JBMetadataResolver.sol";

/**
 * @notice Contract to create structured metadata, storing {id: data} entries.
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
 *
 *         This contract is intended to expose the library functions as a helper for frontends.
 */
contract MetadataResolverHelper {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    /**
     * @notice Parse the metadata to find the data for a specific ID
     *
     * @dev    Returns false and an empty bytes if no data is found
     *
     * @param  _id             The ID to find
     * @param  _metadata       The metadata to parse
     *
     * @return _found          Whether the {id:data} was found
     * @return _targetData The data for the ID (can be empty)
     */
    function getDataFor(
        bytes4 _id,
        bytes calldata _metadata
    )
        public
        pure
        returns (bool _found, bytes memory _targetData)
    {
        return JBMetadataResolver.getDataFor(_id, _metadata);
    }

    /**
     * @notice Create the metadata for a list of {id:data}
     *
     * @dev    Intended for offchain use (gas heavy)
     *
     * @param _ids             The list of ids
     * @param _datas       The list of corresponding datas
     *
     * @return metadata       The resulting metadata
     */
    function createMetadata(
        bytes4[] calldata _ids,
        bytes[] calldata _datas
    )
        public
        pure
        returns (bytes memory metadata)
    {
        return JBMetadataResolver.createMetadata(_ids, _datas);
    }

    /**
     * @notice Add a data entry to an existing metadata
     *
     * @param originalMetadata The original metadata
     * @param idToAdd          The id of the hook to add
     * @param dataToAdd        The metadata of the hook to add
     *
     * @return _newMetadata    The new metadata with the hook added
     */
    function addDataToMetadata(
        bytes calldata originalMetadata,
        bytes4 idToAdd,
        bytes calldata dataToAdd
    )
        public
        pure
        returns (bytes memory)
    {
        return JBMetadataResolver.addToMetadata(originalMetadata, idToAdd, dataToAdd);
    }

    /**
     * @notice Returns an unique id following a suggested format
     *         (`xor(address(this), functionality name)` where functionality name is a string
     *         giving context to the id (Permit2, quoteForSwap, etc)
     *
     * @param _functionality   A string describing the functionality associated with the id
     *
     * @return id       The resulting id
     */
    function getId(string memory _functionality) public view returns (bytes4) {
        return JBMetadataResolver.getId(_functionality);
    }

    function getId(string memory _functionality, address _target) public view returns (bytes4) {
        return JBMetadataResolver.getId(_functionality, _target);
    }

}
