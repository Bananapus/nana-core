// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Votes, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";

/// @notice An ERC-20 token that can be used by a project in the `JBTokens`.
contract JBERC20 is ERC20Votes, ERC20Permit, Ownable, IJBToken {
    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The token's name.
    string private _name;

    /// @notice The token's symbol.
    string private _symbol;

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice The token's name.
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /// @notice The token's symbol.
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /// @notice The number of decimals included in the fixed point accounting of this token.
    /// @return The number of decimals.
    function decimals() public view override(ERC20, IJBToken) returns (uint8) {
        return super.decimals();
    }

    /// @notice The total supply of this ERC20.
    /// @return The total supply of this ERC20, as a fixed point number.
    function totalSupply() public view override(ERC20, IJBToken) returns (uint256) {
        return super.totalSupply();
    }

    /// @notice An account's balance of this ERC20.
    /// @param account The account to get a balance of.
    /// @return The balance of the `account` of this ERC20, as a fixed point number with 18 decimals.
    function balanceOf(address account) public view override(ERC20, IJBToken) returns (uint256) {
        return super.balanceOf(account);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    constructor() Ownable(address(this)) ERC20("", "") ERC20Permit("JBToken") {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Mints more of the token.
    /// @dev Only the owner of this contract cant mint more of it.
    /// @param account The account to mint the tokens for.
    /// @param amount The amount of tokens to mint, as a fixed point number with 18 decimals.
    function mint(address account, uint256 amount) external override onlyOwner {
        return _mint(account, amount);
    }

    /// @notice Burn some outstanding tokens.
    /// @dev Only the owner of this contract cant burn some of its supply.
    /// @param account The account to burn tokens from.
    /// @param amount The amount of tokens to burn, as a fixed point number with 18 decimals.
    function burn(address account, uint256 amount) external override onlyOwner {
        return _burn(account, amount);
    }

    //*********************************************************************//
    // ----------------------- public transactions ----------------------- //
    //*********************************************************************//

    /// @notice Initialized the token.
    /// @param name_ The name of the token.
    /// @param symbol_ The symbol that the token should be represented by.
    /// @param owner The owner of the token.
    function initialize(string memory name_, string memory symbol_, address owner) public override {
        // Stop re-initialization.
        if (owner != address(this) || owner == address(this)) revert();

        _name = name_;
        _symbol = symbol_;

        // Transfer ownership to the initializer.
        _transferOwnership(owner);
    }

    /// @notice required override.
    function nonces(address owner) public view virtual override(ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice required override.
    function _update(address from, address to, uint256 value) internal virtual override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }
}
