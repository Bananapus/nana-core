// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721Votes} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Votes.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBTokenUriResolver} from "./interfaces/IJBTokenUriResolver.sol";

/// @notice Stores project ownership and metadata.
/// @dev Projects are represented as ERC-721s.
contract JBProjects is ERC721Votes, Ownable, IJBProjects {
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The number of projects that have been created using this contract.
    /// @dev The count is incremented with each new project created.
    /// @dev The resulting ERC-721 token ID for each project is the newly incremented count value.
    uint256 public override count = 0;

    /// @notice The contract resolving each project ID to its ERC721 URI.
    IJBTokenUriResolver public override tokenUriResolver;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Returns the URI where the ERC-721 standard JSON of a project is hosted.
    /// @param projectId The ID of the project to get a URI of.
    /// @return The token URI to use for the provided `projectId`.
    function tokenURI(uint256 projectId) public view override returns (string memory) {
        // Keep a reference to the resolver.
        IJBTokenUriResolver resolver = tokenUriResolver;

        // If there's no resolver, there's no URI.
        if (resolver == IJBTokenUriResolver(address(0))) return "";

        // Return the resolved URI.
        return resolver.getUri(projectId);
    }

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherance to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IJBProjects).interfaceId || super.supportsInterface(interfaceId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param owner The owner of the contract who can set metadata.
    constructor(address owner)
        ERC721("Juicebox Projects", "JUICEBOX")
        EIP712("Juicebox Projects", "1")
        Ownable(owner)
    {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Create a new project for the specified owner, which mints an NFT (ERC-721) into their wallet.
    /// @dev Anyone can create a project on an owner's behalf.
    /// @param owner The address that will be the owner of the project.
    /// @return projectId The token ID of the newly created project.
    function createFor(address owner) external override returns (uint256 projectId) {
        // Increment the count, which will be used as the ID.
        projectId = ++count;

        // Mint the project.
        _safeMint(owner, projectId);

        emit Create(projectId, owner, _msgSender());
    }

    /// @notice Sets the address of the resolver used to retrieve the tokenURI of projects.
    /// @param newResolver The address of the new resolver.
    function setTokenUriResolver(IJBTokenUriResolver newResolver) external override onlyOwner {
        // Store the new resolver.
        tokenUriResolver = newResolver;

        emit SetTokenUriResolver(newResolver, _msgSender());
    }
}
