// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IJBFeelessAddresses} from "./interfaces/IJBFeelessAddresses.sol";

/// @notice Stores a list of addresses that shouldn't incur fees when sending or receiving payments.
contract JBFeelessAddresses is Ownable, IJBFeelessAddresses, IERC165 {
    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Check if the specified address is feeless.
    /// @dev Feeless addresses can receive payouts without incurring a fee.
    /// @dev Feeless addresses can use the surplus allowance without incurring a fee.
    /// @dev Feeless addresses can be the beneficary of redemptions without incurring a fee.
    /// @custom:param addr The address to check.
    mapping(address addr => bool) public override isFeeless;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param owner This contract's owner.
    constructor(address owner) Ownable(owner) {}

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

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sets whether an address is feeless.
    /// @dev Can only be called by this contract's owner.
    /// @param addr The address to set as feeless or not feeless.
    /// @param flag Whether the address should be feeless (`true`) or not feeless (`false`).
    function setFeelessAddress(address addr, bool flag) external virtual override onlyOwner {
        isFeeless[addr] = flag;

        emit SetFeelessAddress({ addr: addr, isFeeless: flag, caller: _msgSender() });
    }
}
