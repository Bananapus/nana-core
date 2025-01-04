// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBTokenUriResolver} from "./interfaces/IJBTokenUriResolver.sol";

/// @notice Stores project ownership and metadata.
/// @dev Projects are represented as ERC-721s.
contract JBProjects is ERC721, Ownable, IJBProjects {
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The contract resolving each project ID to its ERC721 URI.
    IJBTokenUriResolver public override tokenUriResolver;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param owner The owner of the contract who can set metadata.
    /// @param feeProjectOwner The address that will receive the fee-project. If `address(0)` the fee-project will not
    /// be minted.
    constructor(address owner, address feeProjectOwner) ERC721("Juicebox Projects", "JUICEBOX") Ownable(owner) {
        if (feeProjectOwner != address(0)) {
            _createFor({ owner: feeProjectOwner, projectId: 1 });
        }
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates whether this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IJBProjects).interfaceId || super.supportsInterface(interfaceId);
    }

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

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets the address of the resolver used to retrieve the tokenURI of projects.
    /// @param resolver The address of the new resolver.
    function setTokenUriResolver(IJBTokenUriResolver resolver) external override onlyOwner {
        // Store the new resolver.
        tokenUriResolver = resolver;

        emit SetTokenUriResolver({resolver: resolver, caller: _msgSender()});
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Create a new project for the specified owner, which mints an NFT (ERC-721) into their wallet.
    /// @dev Anyone can create a project on an owner's behalf.
    /// @param owner The address that will be the owner of the project.
    /// @param salt The salt to use to determine the project ID.
    /// @return projectId The token ID of the newly created project.
    function createFor(address owner, bytes calldata salt) external override returns (uint256 projectId) {
        // Set the project's ID as the hash of the owner and salt.
        projectId = uint56(uint256(keccak256(abi.encode(owner, salt))));

        // Create the project.
        _createFor({ owner: owner, projectId: projectId });
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Create a new project for the specified owner, which mints an NFT (ERC-721) into their wallet.
    /// @dev Anyone can create a project on an owner's behalf.
    /// @param owner The address that will be the owner of the project.
    /// @param projectId The token ID of the newly created project.
    function _createFor(address owner, uint256 projectId) internal {
        emit Create({projectId: projectId, owner: owner, caller: _msgSender()});

        // Mint the project.
        _safeMint(owner, projectId);
    }
}
