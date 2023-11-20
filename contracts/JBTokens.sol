// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {JBControllerUtility} from "./abstract/JBControllerUtility.sol";
import {JBOperatable} from "./abstract/JBOperatable.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBFundingCycleStore} from "./interfaces/IJBFundingCycleStore.sol";
import {IJBOperatorStore} from "./interfaces/IJBOperatorStore.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";
import {IJBTokenStore} from "./interfaces/IJBTokenStore.sol";
import {JBFundingCycleMetadataResolver} from "./libraries/JBFundingCycleMetadataResolver.sol";
import {JBOperations} from "./libraries/JBOperations.sol";
import {JBFundingCycle} from "./structs/JBFundingCycle.sol";
import {JBToken} from "./JBToken.sol";

/// @notice Manage token minting, burning, and account balances.
/// @dev Token balances can be either represented internally or claimed as ERC-20s into wallets. This contract manages these two representations and allows claiming.
/// @dev The total supply of a project's tokens and the balance of each account are calculated in this contract.
/// @dev Each project can bring their own token if they prefer, and swap between tokens at any time.
contract JBTokenStore is JBControllerUtility, JBOperatable, IJBTokenStore {
    // A library that parses the packed funding cycle metadata into a friendlier format.
    using JBFundingCycleMetadataResolver for JBFundingCycle;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error ALREADY_SET();
    error EMPTY_NAME();
    error EMPTY_SYMBOL();
    error EMPTY_TOKEN();
    error INSUFFICIENT_FUNDS();
    error INSUFFICIENT_UNCLAIMED_TOKENS();
    error PROJECT_ALREADY_HAS_TOKEN();
    error RECIPIENT_ZERO_ADDRESS();
    error TOKEN_NOT_FOUND();
    error TOKENS_MUST_HAVE_18_DECIMALS();
    error TRANSFERS_PAUSED();
    error OVERFLOW_ALERT();

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice Mints ERC-721's that represent project ownership and transfers.
    IJBProjects public immutable override projects;

    /// @notice The contract storing all funding cycle configurations.
    IJBFundingCycleStore public immutable override fundingCycleStore;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice Each project's attached token contract.
    /// @custom:param _projectId The ID of the project to which the token belongs.
    mapping(uint256 => IJBToken) public override tokenOf;

    /// @notice Each token's project.
    /// @custom:param _token The address of the token to which the project belongs.
    mapping(IJBToken => uint256) public override projectIdOf;

    /// @notice The total supply of unclaimed tokens for each project.
    /// @custom:param _projectId The ID of the project to which the token belongs.
    mapping(uint256 => uint256) public override unclaimedTotalSupplyOf;

    /// @notice Each holder's balance of unclaimed tokens for each project.
    /// @custom:param _holder The holder of balance.
    /// @custom:param _projectId The ID of the project to which the token belongs.
    mapping(address => mapping(uint256 => uint256)) public override unclaimedBalanceOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The total balance of tokens a holder has for a specified project, including claimed and unclaimed tokens.
    /// @param _holder The token holder to get a balance for.
    /// @param _projectId The project to get the `_holder`s balance of.
    /// @return balance The project token balance of the `_holder
    function balanceOf(address _holder, uint256 _projectId)
        external
        view
        override
        returns (uint256 balance)
    {
        // Get a reference to the holder's unclaimed balance for the project.
        balance = unclaimedBalanceOf[_holder][_projectId];

        // Get a reference to the project's current token.
        IJBToken _token = tokenOf[_projectId];

        // If the project has a current token, add the holder's balance to the total.
        if (_token != IJBToken(address(0))) {
            balance = balance + _token.balanceOf(_holder);
        }
    }

    //*********************************************************************//
    // --------------------------- public views -------------------------- //
    //*********************************************************************//

    /// @notice The total supply of tokens for each project, including claimed and unclaimed tokens.
    /// @param _projectId The ID of the project to get the total token supply of.
    /// @return totalSupply The total supply of the project's tokens.
    function totalSupplyOf(uint256 _projectId) public view override returns (uint256 totalSupply) {
        // Get a reference to the total supply of the project's unclaimed tokens.
        totalSupply = unclaimedTotalSupplyOf[_projectId];

        // Get a reference to the project's current token.
        IJBToken _token = tokenOf[_projectId];

        // If the project has a current token, add its total supply to the total.
        if (_token != IJBToken(address(0))) {
            totalSupply = totalSupply + _token.totalSupply();
        }
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _operatorStore A contract storing operator assignments.
    /// @param _projects A contract which mints ERC-721's that represent project ownership and transfers.
    /// @param _directory A contract storing directories of terminals and controllers for each project.
    /// @param _fundingCycleStore A contract storing all funding cycle configurations.
    constructor(
        IJBOperatorStore _operatorStore,
        IJBProjects _projects,
        IJBDirectory _directory,
        IJBFundingCycleStore _fundingCycleStore
    ) JBOperatable(_operatorStore) JBControllerUtility(_directory) {
        projects = _projects;
        fundingCycleStore = _fundingCycleStore;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Issues a project's ERC-20 tokens that'll be used when claiming tokens.
    /// @dev Deploys a project's ERC-20 token contract.
    /// @dev Only a project's owner or operator can issue its token.
    /// @param _projectId The ID of the project being issued tokens.
    /// @param _name The ERC-20's name.
    /// @param _symbol The ERC-20's symbol.
    /// @return token The token that was issued.
    function issueFor(uint256 _projectId, string calldata _name, string calldata _symbol)
        external
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.ISSUE_TOKEN)
        returns (IJBToken token)
    {
        // There must be a name.
        if (bytes(_name).length == 0) revert EMPTY_NAME();

        // There must be a symbol.
        if (bytes(_symbol).length == 0) revert EMPTY_SYMBOL();

        // The project shouldn't already have a token.
        if (tokenOf[_projectId] != IJBToken(address(0))) revert PROJECT_ALREADY_HAS_TOKEN();

        // Deploy the token contract.
        token = new JBToken(_name, _symbol, address(this));

        // Store the token contract.
        tokenOf[_projectId] = token;

        // Store the project for the token.
        projectIdOf[token] = _projectId;

        emit Issue(_projectId, token, _name, _symbol, msg.sender);
    }

    /// @notice Set a project's token if not already set.
    /// @dev Only a project's owner or operator can set its token.
    /// @param _projectId The ID of the project to which the set token belongs.
    /// @param _token The new token.
    function setFor(uint256 _projectId, IJBToken _token)
        external
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBOperations.SET_TOKEN)
    {
        // Can't set to the zero address.
        if (_token == IJBToken(address(0))) revert EMPTY_TOKEN();

        // Can't set token if the project is already associated with another token.
        if (tokenOf[_projectId] != IJBToken(address(0))) revert ALREADY_SET();

        // Can't set token if its already associated with another project.
        if (projectIdOf[_token] != 0) revert ALREADY_SET();

        // Can't change to a token that doesn't use 18 decimals.
        if (_token.decimals() != 18) revert TOKENS_MUST_HAVE_18_DECIMALS();

        // Store the new token.
        tokenOf[_projectId] = _token;

        // Store the project for the token.
        projectIdOf[_token] = _projectId;

        emit Set(_projectId, _token, msg.sender);
    }

    /// @notice Mint new project tokens.
    /// @dev Only a project's current controller can mint its tokens.
    /// @param _holder The address receiving the new tokens.
    /// @param _projectId The ID of the project to which the tokens belong.
    /// @param _amount The amount of tokens to mint.
    function mintFor(address _holder, uint256 _projectId, uint256 _amount)
        external
        override
        onlyController(_projectId)
    {
        // Get a reference to the project's current token.
        IJBToken _token = tokenOf[_projectId];

        // Save a reference to whether there exists a token.
        bool _shouldClaimTokens = _token != IJBToken(address(0));

        if (_shouldClaimTokens) {
            // If tokens should be claimed, mint tokens into the holder's wallet.
            _token.mint(_holder, _amount);
        } else {
            // Otherwise, add the tokens to the unclaimed balance and total supply.
            unclaimedBalanceOf[_holder][_projectId] =
                unclaimedBalanceOf[_holder][_projectId] + _amount;
            unclaimedTotalSupplyOf[_projectId] = unclaimedTotalSupplyOf[_projectId] + _amount;
        }

        // The total supply can't exceed the maximum value storable in a uint224.
        if (totalSupplyOf(_projectId) > type(uint224).max) revert OVERFLOW_ALERT();

        emit Mint(_holder, _projectId, _amount, _shouldClaimTokens, msg.sender);
    }

    /// @notice Burns a project's tokens.
    /// @dev Only a project's current controller can burn its tokens.
    /// @param _holder The address that owns the tokens being burned.
    /// @param _projectId The ID of the project to which the burned tokens belong.
    /// @param _amount The amount of tokens to burn.
    function burnFrom(address _holder, uint256 _projectId, uint256 _amount)
        external
        override
        onlyController(_projectId)
    {
        // Get a reference to the project's current token.
        IJBToken _token = tokenOf[_projectId];

        // Get a reference to the amount of unclaimed project tokens the holder has.
        uint256 _unclaimedBalance = unclaimedBalanceOf[_holder][_projectId];

        // Get a reference to the amount of the project's current token the holder has in their wallet.
        uint256 _claimedBalance = _token == IJBToken(address(0)) ? 0 : _token.balanceOf(_holder);

        // There must be adequate tokens to burn across the holder's claimed and unclaimed balance.
        if (_amount > _claimedBalance + _unclaimedBalance) revert INSUFFICIENT_FUNDS();

        // The amount of tokens to burn.
        uint256 _claimedTokensToBurn;

        // Get a reference to how many claimed tokens should be burned
        if (_claimedBalance != 0) {
            // Burn unclaimed tokens before claimed tokens.
            unchecked {
                _claimedTokensToBurn = _unclaimedBalance < _amount ? _amount - _unclaimedBalance : 0;
            }
        }

        // The amount of unclaimed tokens to burn.
        uint256 _unclaimedTokensToBurn;
        unchecked {
            _unclaimedTokensToBurn = _amount - _claimedTokensToBurn;
        }

        // Subtract the tokens from the unclaimed balance and total supply.
        if (_unclaimedTokensToBurn > 0) {
            // Reduce the holders balance and the total supply.
            unclaimedBalanceOf[_holder][_projectId] =
                unclaimedBalanceOf[_holder][_projectId] - _unclaimedTokensToBurn;
            unclaimedTotalSupplyOf[_projectId] =
                unclaimedTotalSupplyOf[_projectId] - _unclaimedTokensToBurn;
        }

        // Burn the claimed tokens.
        if (_claimedTokensToBurn > 0) _token.burn(_holder, _claimedTokensToBurn);

        emit Burn(_holder, _projectId, _amount, _unclaimedBalance, _claimedBalance, msg.sender);
    }

    /// @notice Claims internally accounted for tokens into a holder's wallet.
    /// @dev Only a token holder or an operator specified by the token holder can claim its unclaimed tokens.
    /// @param _holder The owner of the tokens being claimed.
    /// @param _projectId The ID of the project whose tokens are being claimed.
    /// @param _amount The amount of tokens to claim.
    /// @param _beneficiary The account into which the claimed tokens will go.
    function claimFor(address _holder, uint256 _projectId, uint256 _amount, address _beneficiary)
        external
        override
        requirePermission(_holder, _projectId, JBOperations.CLAIM_TOKENS)
    {
        // Get a reference to the project's current token.
        IJBToken _token = tokenOf[_projectId];

        // The project must have a token contract attached.
        if (_token == IJBToken(address(0))) revert TOKEN_NOT_FOUND();

        // Get a reference to the amount of unclaimed project tokens the holder has.
        uint256 _unclaimedBalance = unclaimedBalanceOf[_holder][_projectId];

        // There must be enough unclaimed tokens to claim.
        if (_unclaimedBalance < _amount) revert INSUFFICIENT_UNCLAIMED_TOKENS();

        unchecked {
            // Subtract the claim amount from the holder's unclaimed project token balance.
            unclaimedBalanceOf[_holder][_projectId] = _unclaimedBalance - _amount;

            // Subtract the claim amount from the project's unclaimed total supply.
            unclaimedTotalSupplyOf[_projectId] = unclaimedTotalSupplyOf[_projectId] - _amount;
        }

        // Mint the equivalent amount of the project's token for the holder.
        _token.mint(_beneficiary, _amount);

        emit Claim(_holder, _projectId, _unclaimedBalance, _amount, _beneficiary, msg.sender);
    }

    /// @notice Allows a holder to transfer unclaimed tokens to another account.
    /// @dev Only a token holder or an operator can transfer its unclaimed tokens.
    /// @param _holder The address to transfer tokens from.
    /// @param _projectId The ID of the project whose tokens are being transferred.
    /// @param _recipient The recipient of the tokens.
    /// @param _amount The amount of tokens to transfer.
    function transferFrom(address _holder, uint256 _projectId, address _recipient, uint256 _amount)
        external
        override
        requirePermission(_holder, _projectId, JBOperations.TRANSFER_TOKENS)
    {
        // Get a reference to the current funding cycle for the project.
        JBFundingCycle memory _fundingCycle = fundingCycleStore.currentOf(_projectId);

        // Must not be paused.
        if (_fundingCycle.global().pauseTransfers) revert TRANSFERS_PAUSED();

        // Can't transfer to the zero address.
        if (_recipient == address(0)) revert RECIPIENT_ZERO_ADDRESS();

        // Get a reference to the holder's unclaimed project token balance.
        uint256 _unclaimedBalance = unclaimedBalanceOf[_holder][_projectId];

        // The holder must have enough unclaimed tokens to transfer.
        if (_amount > _unclaimedBalance) revert INSUFFICIENT_UNCLAIMED_TOKENS();

        // Subtract from the holder's unclaimed token balance.
        unchecked {
            unclaimedBalanceOf[_holder][_projectId] = _unclaimedBalance - _amount;
        }

        // Add the unclaimed project tokens to the recipient's balance.
        unclaimedBalanceOf[_recipient][_projectId] =
            unclaimedBalanceOf[_recipient][_projectId] + _amount;

        emit Transfer(_holder, _projectId, _recipient, _amount, msg.sender);
    }
}
