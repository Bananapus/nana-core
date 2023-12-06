// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20Votes, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import {ERC20Permit, Nonces} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";

/// @notice An ERC-20 token that can be used by a project in the `JBTokens`.
contract JBERC20 is ERC20Votes, ERC20Permit, Ownable, IJBToken {
    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

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
    /// @param _account The account to get a balance of.
    /// @return The balance of the `_account` of this ERC20, as a fixed point number with 18 decimals.
    function balanceOf(address _account) public view override(ERC20, IJBToken) returns (uint256) {
        return super.balanceOf(_account);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _name The name of the token.
    /// @param _symbol The symbol that the token should be represented by.
    /// @param _owner The owner of the token.
    constructor(string memory _name, string memory _symbol, address _owner)
        ERC20(_name, _symbol)
        ERC20Permit(_name)
        Ownable(_owner)
    {}

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Mints more of the token.
    /// @dev Only the owner of this contract cant mint more of it.
    /// @param _account The account to mint the tokens for.
    /// @param _amount The amount of tokens to mint, as a fixed point number with 18 decimals.
    function mint(address _account, uint256 _amount) external override onlyOwner {
        return _mint(_account, _amount);
    }

    /// @notice Burn some outstanding tokens.
    /// @dev Only the owner of this contract cant burn some of its supply.
    /// @param _account The account to burn tokens from.
    /// @param _amount The amount of tokens to burn, as a fixed point number with 18 decimals.
    function burn(address _account, uint256 _amount) external override onlyOwner {
        return _burn(_account, _amount);
    }

    /// @notice required override.
    function nonces(address owner)
        public
        view
        virtual
        override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    /// @notice required override.
    function _update(address from, address to, uint256 value)
        internal
        virtual
        override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }
}
