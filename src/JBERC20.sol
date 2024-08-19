// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20Votes} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";

import {IJBToken} from "./interfaces/IJBToken.sol";

/// @notice An ERC-20 token that can be used by a project in `JBTokens` and `JBController`.
/// @dev By default, a project uses "credits" to track balances. Once a project sets their `IJBToken` using
/// `JBController.deployERC20For(...)` or `JBController.setTokenFor(...)`, credits can be redeemed to claim tokens.
/// @dev `JBController.deployERC20For(...)` deploys a `JBERC20` contract and sets it as the project's token.
contract JBERC20 is ERC20Votes, ERC20Permit, Ownable, IJBToken {
    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The token's name.
    // slither-disable-next-line shadowing-state
    string private _name;

    /// @notice The token's symbol.
    // slither-disable-next-line shadowing-state
    string private _symbol;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    constructor() Ownable(address(this)) ERC20("invalid", "invalid") ERC20Permit("JBToken") {}

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The balance of the given address.
    /// @param account The account to get the balance of.
    /// @return The number of tokens owned by the `account`, as a fixed point number with 18 decimals.
    function balanceOf(address account) public view override(ERC20, IJBToken) returns (uint256) {
        return super.balanceOf(account);
    }

    /// @notice The number of decimals used for this token's fixed point accounting.
    /// @return The number of decimals.
    function decimals() public view override(ERC20, IJBToken) returns (uint8) {
        return super.decimals();
    }

    /// @notice The token's name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice The token's symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice The total supply of this ERC20 i.e. the total number of tokens in existence.
    /// @return The total supply of this ERC20, as a fixed point number.
    function totalSupply() public view override(ERC20, IJBToken) returns (uint256) {
        return super.totalSupply();
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Burn some outstanding tokens.
    /// @dev Can only be called by this contract's owner.
    /// @param account The address to burn tokens from.
    /// @param amount The amount of tokens to burn, as a fixed point number with 18 decimals.
    function burn(address account, uint256 amount) external override onlyOwner {
        return _burn(account, amount);
    }

    /// @notice Mints more of this token.
    /// @dev Can only be called by this contract's owner.
    /// @param account The address to mint the new tokens to.
    /// @param amount The amount of tokens to mint, as a fixed point number with 18 decimals.
    function mint(address account, uint256 amount) external override onlyOwner {
        return _mint(account, amount);
    }

    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************//

    /// @notice Initializes the token.
    /// @param name_ The token's name.
    /// @param symbol_ The token's symbol.
    /// @param owner The token contract's owner.
    function initialize(string memory name_, string memory symbol_, address owner) public override {
        // Prevent re-initialization by reverting if a name is already set or if the provided name is empty.
        if (bytes(_name).length != 0 || bytes(name_).length == 0) revert();

        _name = name_;
        _symbol = symbol_;

        // Transfer ownership to the owner.
        _transferOwnership(owner);
    }

    /// @notice Required override.
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Required override.
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
}
