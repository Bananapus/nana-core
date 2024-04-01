// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IJBFeelessAddresses} from "./interfaces/IJBFeelessAddresses.sol";

/// @notice Stores and manages addresses that shouldn't incur fees when being paid towards or from.
contract JBFeelessAddresses is Ownable, ERC165, IJBFeelessAddresses {
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Feeless addresses for this terminal.
    /// @dev Feeless addresses can receive payouts without incurring a fee.
    /// @dev Feeless addresses can use the surplus allowance without incurring a fee.
    /// @dev Feeless addresses can be the beneficary of redemptions without incurring a fee.
    /// @custom:param addr The address that may or may not be feeless.
    mapping(address addr => bool) public override isFeeless;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates whether this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IJBFeelessAddresses).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @param owner The address that will own this contract.
    constructor(address owner) Ownable(owner) {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets an address as feeless or not feeless for this terminal.
    /// @dev Only the owner of this contract can set addresses as feeless or not feeless.
    /// @dev Feeless addresses can receive payouts without incurring a fee.
    /// @dev Feeless addresses can use the surplus allowance without incurring a fee.
    /// @dev Feeless addresses can be the beneficary of redemptions without incurring a fee.
    /// @param addr The address to make feeless or not feeless.
    /// @param flag A flag indicating whether the `address` should be made feeless or not feeless.
    function setFeelessAddress(address addr, bool flag) external virtual override onlyOwner {
        // Set the flag value.
        isFeeless[addr] = flag;

        emit SetFeelessAddress(addr, flag, _msgSender());
    }
}
