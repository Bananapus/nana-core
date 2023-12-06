// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IJBTokenUriResolver} from "./IJBTokenUriResolver.sol";

interface IJBProjects is IERC721 {
    event Create(uint256 indexed projectId, address indexed owner, address caller);

    event SetTokenUriResolver(IJBTokenUriResolver indexed resolver, address caller);

    function count() external view returns (uint256);

    function tokenUriResolver() external view returns (IJBTokenUriResolver);

    function createFor(address owner) external returns (uint256 projectId);

    function setTokenUriResolver(IJBTokenUriResolver newResolver) external;
}
