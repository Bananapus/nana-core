// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {JBControlled} from "./abstract/JBControlled.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";
import {IJBTokens} from "./interfaces/IJBTokens.sol";
import {JBERC20} from "./JBERC20.sol";

/// @notice Manages minting, burning, and balances of projects' tokens and token credits.
/// @dev Token balances can either be ERC-20s or token credits. This contract manages these two representations and
/// allows credit -> ERC-20 claiming.
/// @dev The total supply of a project's tokens and the balance of each account are calculated in this contract.
/// @dev An ERC-20 contract must be set by a project's owner for ERC-20 claiming to become available. Projects can bring
/// their own IJBToken if they prefer.
contract JBTokens is JBControlled, IJBTokens {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error TOKEN_ALREADY_SET();
    error EMPTY_NAME();
    error EMPTY_SYMBOL();
    error EMPTY_TOKEN();
    error INSUFFICIENT_FUNDS();
    error INSUFFICIENT_CREDITS();
    error PROJECT_ALREADY_HAS_TOKEN();
    error RECIPIENT_ZERO_ADDRESS();
    error TOKEN_NOT_FOUND();
    error TOKENS_MUST_HAVE_18_DECIMALS();
    error OVERFLOW_ALERT();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    IJBToken public immutable TOKEN;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Each project's attached token contract.
    /// @custom:param projectId The ID of the project the token belongs to.
    mapping(uint256 projectId => IJBToken) public override tokenOf;

    /// @notice Each token's project.
    /// @custom:param token The address of the token associated with the project.
    mapping(IJBToken token => uint256) public override projectIdOf;

    /// @notice The total supply of credits for each project.
    /// @custom:param projectId The ID of the project to which the credits belong.
    mapping(uint256 projectId => uint256) public override totalCreditSupplyOf;

    /// @notice Each holder's credit balance for each project.
    /// @custom:param holder The credit holder.
    /// @custom:param projectId The ID of the project to which the credits belong.
    mapping(address holder => mapping(uint256 projectId => uint256)) public override creditBalanceOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The total balance a holder has for a specified project, including both tokens and token credits.
    /// @param holder The holder to get a balance for.
    /// @param projectId The project to get the `_holder`s balance for.
    /// @return balance The combined token and token credit balance of the `_holder
    function totalBalanceOf(address holder, uint256 projectId) external view override returns (uint256 balance) {
        // Get a reference to the holder's credits for the project.
        balance = creditBalanceOf[holder][projectId];

        // Get a reference to the project's current token.
        IJBToken token = tokenOf[projectId];

        // If the project has a current token, add the holder's balance to the total.
        if (token != IJBToken(address(0))) {
            balance = balance + token.balanceOf(holder);
        }
    }

    //*********************************************************************//
    // --------------------------- public views -------------------------- //
    //*********************************************************************//

    /// @notice The total supply for a specific project, including both tokens and token credits.
    /// @param projectId The ID of the project to get the total supply of.
    /// @return totalSupply The total supply of the project's tokens and token credits.
    function totalSupplyOf(uint256 projectId) public view override returns (uint256 totalSupply) {
        // Get a reference to the total supply of the project's credits
        totalSupply = totalCreditSupplyOf[projectId];

        // Get a reference to the project's current token.
        IJBToken token = tokenOf[projectId];

        // If the project has a current token, add its total supply to the total.
        if (token != IJBToken(address(0))) {
            totalSupply = totalSupply + token.totalSupply();
        }
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    /// @param token The implementation of the token contract that project can deploy.
    constructor(IJBDirectory directory, IJBToken token) JBControlled(directory) {
        TOKEN = token;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Deploys an ERC-20 token for a project. It will be used when claiming tokens.
    /// @dev Deploys a project's ERC-20 token contract.
    /// @dev Only a project's controller can deploy its token.
    /// @param projectId The ID of the project to deploy an ERC-20 token for.
    /// @param name The ERC-20's name.
    /// @param symbol The ERC-20's symbol.
    /// @return token The address of the token that was deployed.
    function deployERC20For(
        uint256 projectId,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    )
        external
        override
        onlyControllerOf(projectId)
        returns (IJBToken token)
    {
        // There must be a name.
        if (bytes(name).length == 0) revert EMPTY_NAME();

        // There must be a symbol.
        if (bytes(symbol).length == 0) revert EMPTY_SYMBOL();

        // The project shouldn't already have a token.
        if (tokenOf[projectId] != IJBToken(address(0))) revert PROJECT_ALREADY_HAS_TOKEN();

        token = salt == bytes32(0)
            ? IJBToken(Clones.clone(address(TOKEN)))
            : IJBToken(Clones.cloneDeterministic(address(TOKEN), keccak256(abi.encode(msg.sender, salt))));

        // Initialize the token.
        token.initialize({name: name, symbol: symbol, owner: address(this)});

        // Store the token contract.
        tokenOf[projectId] = token;

        // Store the project for the token.
        projectIdOf[token] = projectId;

        emit DeployERC20(projectId, token, name, symbol, salt, msg.sender);
    }

    /// @notice Set a project's token if not already set.
    /// @dev Only a project's controller can set its token.
    /// @param projectId The ID of the project to set the token of.
    /// @param token The new token's address.
    function setTokenFor(uint256 projectId, IJBToken token) external override onlyControllerOf(projectId) {
        // Can't set to the zero address.
        if (token == IJBToken(address(0))) revert EMPTY_TOKEN();

        // Can't set a token if the project is already associated with another token.
        if (tokenOf[projectId] != IJBToken(address(0))) revert TOKEN_ALREADY_SET();

        // Can't set a token if it's already associated with another project.
        if (projectIdOf[token] != 0) revert TOKEN_ALREADY_SET();

        // Can't change to a token that doesn't use 18 decimals.
        if (token.decimals() != 18) revert TOKENS_MUST_HAVE_18_DECIMALS();

        // Store the new token.
        tokenOf[projectId] = token;

        // Store the project for the token.
        projectIdOf[token] = projectId;

        emit SetToken(projectId, token, msg.sender);
    }

    /// @notice Mint (create) new tokens or credits.
    /// @dev Only a project's current controller can mint its tokens.
    /// @param holder The address receiving the new tokens.
    /// @param projectId The ID of the project to which the tokens belong.
    /// @param amount The amount of tokens to mint.
    function mintFor(address holder, uint256 projectId, uint256 amount) external override onlyControllerOf(projectId) {
        // Get a reference to the project's current token.
        IJBToken token = tokenOf[projectId];

        // Save a reference to whether there a token exists.
        bool shouldClaimTokens = token != IJBToken(address(0));

        if (shouldClaimTokens) {
            // If tokens should be claimed, mint tokens into the holder's wallet.
            token.mint(holder, amount);
        } else {
            // Otherwise, add the tokens to their credits and the credit supply.
            creditBalanceOf[holder][projectId] = creditBalanceOf[holder][projectId] + amount;
            totalCreditSupplyOf[projectId] = totalCreditSupplyOf[projectId] + amount;
        }

        // The total supply can't exceed the maximum value storable in a uint208.
        if (totalSupplyOf(projectId) > type(uint208).max) revert OVERFLOW_ALERT();

        emit Mint(holder, projectId, amount, shouldClaimTokens, msg.sender);
    }

    /// @notice Burns (destroys) credits or tokens.
    /// @dev Credits are burned first, then tokens are burned.
    /// @dev Only a project's current controller can burn its tokens.
    /// @param holder The address that owns the tokens which are being burned.
    /// @param projectId The ID of the project to the burned tokens belong to.
    /// @param amount The amount of tokens to burn.
    function burnFrom(
        address holder,
        uint256 projectId,
        uint256 amount
    )
        external
        override
        onlyControllerOf(projectId)
    {
        // Get a reference to the project's current token.
        IJBToken token = tokenOf[projectId];

        // Get a reference to the amount of credits the holder has.
        uint256 creditBalance = creditBalanceOf[holder][projectId];

        // Get a reference to the amount of the project's current token the holder has in their wallet.
        uint256 tokenBalance = token == IJBToken(address(0)) ? 0 : token.balanceOf(holder);

        // There must be enough tokens to burn across the holder's combined token and credit balance.
        if (amount > tokenBalance + creditBalance) revert INSUFFICIENT_FUNDS();

        // The amount of tokens to burn.
        uint256 tokensToBurn;

        // Get a reference to how many tokens should be burned
        if (tokenBalance != 0) {
            // Burn credits before tokens.
            unchecked {
                tokensToBurn = creditBalance < amount ? amount - creditBalance : 0;
            }
        }

        // The amount of credits to burn.
        uint256 creditsToBurn;
        unchecked {
            creditsToBurn = amount - tokensToBurn;
        }

        // Subtract the burned credits from the credit balance and credit supply.
        if (creditsToBurn > 0) {
            creditBalanceOf[holder][projectId] = creditBalanceOf[holder][projectId] - creditsToBurn;
            totalCreditSupplyOf[projectId] = totalCreditSupplyOf[projectId] - creditsToBurn;
        }

        // Burn the tokens.
        if (tokensToBurn > 0) token.burn(holder, tokensToBurn);

        emit Burn(holder, projectId, amount, creditBalance, tokenBalance, msg.sender);
    }

    /// @notice Redeem credits to claim tokens into a holder's wallet.
    /// @dev Only a project's controller can claim that project's tokens.
    /// @param holder The owner of the credits being redeemed.
    /// @param projectId The ID of the project whose tokens are being claimed.
    /// @param amount The amount of tokens to claim.
    /// @param beneficiary The account into which the claimed tokens will go.
    function claimTokensFor(
        address holder,
        uint256 projectId,
        uint256 amount,
        address beneficiary
    )
        external
        override
        onlyControllerOf(projectId)
    {
        // Get a reference to the project's current token.
        IJBToken token = tokenOf[projectId];

        // The project must have a token contract attached.
        if (token == IJBToken(address(0))) revert TOKEN_NOT_FOUND();

        // Get a reference to the amount of credits the holder has.
        uint256 creditBalance = creditBalanceOf[holder][projectId];

        // There must be enough credits to claim.
        if (creditBalance < amount) revert INSUFFICIENT_CREDITS();

        unchecked {
            // Subtract the claim amount from the holder's credit balance.
            creditBalanceOf[holder][projectId] = creditBalance - amount;

            // Subtract the claim amount from the project's total credit supply.
            totalCreditSupplyOf[projectId] = totalCreditSupplyOf[projectId] - amount;
        }

        // Mint the equivalent amount of the project's token for the holder.
        token.mint(beneficiary, amount);

        emit ClaimTokens(holder, projectId, creditBalance, amount, beneficiary, msg.sender);
    }

    /// @notice Allows a holder to transfer credits to another account.
    /// @dev Only a project's controller can transfer credits for that project.
    /// @param holder The address to transfer credits from.
    /// @param projectId The ID of the project whose credits are being transferred.
    /// @param recipient The recipient of the credits.
    /// @param amount The amount of credits to transfer.
    function transferCreditsFrom(
        address holder,
        uint256 projectId,
        address recipient,
        uint256 amount
    )
        external
        override
        onlyControllerOf(projectId)
    {
        // Can't transfer to the zero address.
        if (recipient == address(0)) revert RECIPIENT_ZERO_ADDRESS();

        // Get a reference to the holder's unclaimed project token balance.
        uint256 creditBalance = creditBalanceOf[holder][projectId];

        // The holder must have enough unclaimed tokens to transfer.
        if (amount > creditBalance) revert INSUFFICIENT_CREDITS();

        // Subtract from the holder's unclaimed token balance.
        unchecked {
            creditBalanceOf[holder][projectId] = creditBalance - amount;
        }

        // Add the unclaimed project tokens to the recipient's balance.
        creditBalanceOf[recipient][projectId] = creditBalanceOf[recipient][projectId] + amount;

        emit TransferCredits(holder, projectId, recipient, amount, msg.sender);
    }
}
