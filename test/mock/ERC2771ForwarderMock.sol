// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

struct ForwardRequest {
    address from;
    address to;
    uint256 value;
    uint256 gas;
    uint256 nonce;
    uint48 deadline;
    bytes data;
}

contract ERC2771ForwarderMock is ERC2771Forwarder {
    bool public deployed = true;

    constructor(string memory name) ERC2771Forwarder(name) {}

    function structHash(ForwardRequest calldata request) external view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _FORWARD_REQUEST_TYPEHASH,
                    request.from,
                    request.to,
                    request.value,
                    request.gas,
                    request.nonce,
                    request.deadline,
                    keccak256(request.data)
                )
            )
        );
    }
}
