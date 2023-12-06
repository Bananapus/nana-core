// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {PRBMath} from "@paulrberg/contracts/math/PRBMath.sol";
import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {JBApprovalStatus} from "./enums/JBApprovalStatus.sol";
import {IJBController} from "./interfaces/IJBController.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBFundAccessLimits} from "./interfaces/IJBFundAccessLimits.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
import {IJBDirectoryAccessControl} from "./interfaces/IJBDirectoryAccessControl.sol";
import {IJBMigratable} from "./interfaces/IJBMigratable.sol";
import {IJBPermissioned} from "./interfaces/IJBPermissioned.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBTerminal} from "./interfaces/terminal/IJBTerminal.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBProjectMetadataRegistry} from "./interfaces/IJBProjectMetadataRegistry.sol";
import {IJBSplitHook} from "./interfaces/IJBSplitHook.sol";
import {IJBSplits} from "./interfaces/IJBSplits.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";
import {IJBTokens} from "./interfaces/IJBTokens.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBRulesetMetadataResolver} from "./libraries/JBRulesetMetadataResolver.sol";
import {JBPermissionIds} from "./libraries/JBPermissionIds.sol";
import {JBSplitGroupIds} from "./libraries/JBSplitGroupIds.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";
import {JBRulesetConfig} from "./structs/JBRulesetConfig.sol";
import {JBRulesetMetadata} from "./structs/JBRulesetMetadata.sol";
import {JBTerminalConfig} from "./structs/JBTerminalConfig.sol";
import {JBSplit} from "./structs/JBSplit.sol";
import {JBSplitGroup} from "./structs/JBSplitGroup.sol";
import {JBSplitHookPayload} from "./structs/JBSplitHookPayload.sol";

/// @notice Stitches together rulesets and project tokens, making sure all activity is accounted for and correct.
contract JBController is JBPermissioned, ERC2771Context, ERC165, IJBController, IJBMigratable {
    // A library that parses packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error RULESET_ALREADY_LAUNCHED();
    error INVALID_BASE_CURRENCY();
    error INVALID_REDEMPTION_RATE();
    error INVALID_RESERVED_RATE();
    error CONTROLLER_MIGRATION_NOT_ALLOWED();
    error MINT_NOT_ALLOWED_AND_NOT_TERMINAL_HOOK();
    error NO_BURNABLE_TOKENS();
    error CREDIT_TRANSFERS_PAUSED();
    error ZERO_TOKENS_TO_MINT();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice Mints ERC-721s that represent project ownership and transfers.
    IJBProjects public immutable override projects;

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public immutable override rulesets;

    /// @notice The contract that manages token minting and burning.
    IJBTokens public immutable override tokens;

    /// @notice The contract that stores splits for each project.
    IJBSplits public immutable override splits;

    /// @notice A contract that stores fund access limits for each project.
    IJBFundAccessLimits public immutable override fundAccessLimits;

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override directory;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The reserved token balance that has not yet been realized (sent out to the reserved split group) for a project.
    /// @custom:param projectId The ID of the project to get the pending reserved token balance of.
    mapping(uint256 => uint256) public override pendingReservedTokenBalanceOf;

    /// @notice The metadata for each project, which can be used across several domains.
    /// @custom:param _projectId The ID of the project to which the metadata belongs.
    mapping(uint256 => string) public override metadataOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the current token supply of a project, including pending reserved tokens.
    /// @param _projectId The ID of the project to get the total token supply of.
    /// @return The current total token supply of the project, including pending reserved tokens that have not been sent to splits yet.
    function totalTokenSupplyWithReservedTokensOf(uint256 _projectId)
        external
        view
        override
        returns (uint256)
    {
        // Add the reserved tokens to the total supply.
        return tokens.totalSupplyOf(_projectId) + pendingReservedTokenBalanceOf[_projectId];
    }

    /// @notice A get `JBRuleset` and `JBRulesetMetadata` structs for the specified `rulesetId`.
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @return ruleset The ruleset as a `JBRuleset` struct.
    /// @return metadata The ruleset's metadata as a `JBRulesetMetadata` struct.
    function getRulesetOf(uint256 _projectId, uint256 _rulesetId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata)
    {
        ruleset = rulesets.getRulesetOf(_projectId, _rulesetId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice The latest ruleset queued for a project. Returns the ruleset's struct, its current approval status, and its metadata.
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @return ruleset The latest queued ruleset as a `JBRuleset` struct.
    /// @return metadata The latest queued ruleset's metadata as a `JBRulesetMetadata` struct.
    /// @return approvalStatus The approval status of the ruleset.
    function latestQueuedRulesetOf(uint256 _projectId)
        external
        view
        override
        returns (
            JBRuleset memory ruleset,
            JBRulesetMetadata memory metadata,
            JBApprovalStatus approvalStatus
        )
    {
        (ruleset, approvalStatus) = rulesets.latestQueuedRulesetOf(_projectId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice A project's current ruleset along with its metadata.
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @return ruleset The current ruleset as a `JBRuleset` struct.
    /// @return metadata The current ruleset's metadata as a `JBRulesetMetadata` struct.
    function currentRulesetOf(uint256 _projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata)
    {
        ruleset = rulesets.currentOf(_projectId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice A project's queued ruleset along with its metadata.
    /// @param _projectId The ID of the project the ruleset belongs to.
    /// @return ruleset The queued ruleset as a `JBRuleset` struct.
    /// @return metadata The queued ruleset's metadata as a `JBRulesetMetadata` struct.
    function queuedRulesetOf(uint256 _projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata)
    {
        ruleset = rulesets.upcomingRulesetOf(_projectId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice A flag indicating if the project currently allows terminals to be set.
    /// @param _projectId The ID of the project the flag is for.
    /// @return The flag
    function setTerminalsAllowed(uint256 _projectId) external view returns (bool) {
        return rulesets.currentOf(_projectId).expandMetadata().allowSetTerminals;
    }

    /// @notice A flag indicating if the project currently allows its controller to be set.
    /// @param _projectId The ID of the project the flag is for.
    /// @return The flag
    function setControllerAllowed(uint256 _projectId) external view returns (bool) {
        return rulesets.currentOf(_projectId).expandMetadata().allowSetController;
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates if this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param _interfaceId The ID of the interface to check for adherance to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return _interfaceId == type(IJBController).interfaceId
            || _interfaceId == type(IJBProjectMetadataRegistry).interfaceId
            || _interfaceId == type(IJBDirectoryAccessControl).interfaceId
            || _interfaceId == type(IJBMigratable).interfaceId
            || _interfaceId == type(IJBPermissioned).interfaceId
            || super.supportsInterface(_interfaceId);
    }

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param _permissions A contract storing permissions.
    /// @param _projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param _directory A contract storing directories of terminals and controllers for each project.
    /// @param _rulesets A contract storing and managing project rulesets.
    /// @param _tokens A contract that manages token minting and burning.
    /// @param _splits A contract that stores splits for each project.
    /// @param _fundAccessLimits A contract that stores fund access limits for each project.
    constructor(
        IJBPermissions _permissions,
        IJBProjects _projects,
        IJBDirectory _directory,
        IJBRulesets _rulesets,
        IJBTokens _tokens,
        IJBSplits _splits,
        IJBFundAccessLimits _fundAccessLimits,
        address _trustedForwarder
    ) JBPermissioned(_permissions) ERC2771Context(_trustedForwarder) {
        projects = _projects;
        directory = _directory;
        rulesets = _rulesets;
        tokens = _tokens;
        splits = _splits;
        fundAccessLimits = _fundAccessLimits;
    }

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
    //*********************************************************************//

    /// @notice Creates a project. This will mint the project's ERC-721 to the specified owner's account, queue its first ruleset, and set up any splits.
    /// @dev Each operation within this transaction can be done in sequence separately.
    /// @dev Anyone can deploy a project on an owner's behalf.
    /// @param _owner The address to set as the owner of the project. The project ERC-721 will be owned by this address.
    /// @param _projectMetadata Metadata to associate with the project. This can be updated any time by the owner of the project.
    /// @param _rulesetConfigurations The ruleset configurations to queue.
    /// @param _terminalConfigurations The terminal configurations to add for the project.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return projectId The ID of the project.
    function launchProjectFor(
        address _owner,
        string calldata _projectMetadata,
        JBRulesetConfig[] calldata _rulesetConfigurations,
        JBTerminalConfig[] calldata _terminalConfigurations,
        string memory _memo
    ) external virtual override returns (uint256 projectId) {
        // Keep a reference to the directory.
        IJBDirectory _directory = directory;

        // Mint the project into the wallet of the owner.
        projectId = projects.createFor(_owner);

        // Set project metadata if one was provided.
        if (bytes(_projectMetadata).length > 0) {
            metadataOf[projectId] = _projectMetadata;
        }

        // Set this contract as the project's controller in the directory.
        _directory.setControllerOf(projectId, IERC165(this));

        // Queue the first ruleset.
        uint256 _rulesetId = _queueRulesets(projectId, _rulesetConfigurations);

        // Configure the terminals.
        _configureTerminals(projectId, _terminalConfigurations);

        emit LaunchProject(_rulesetId, projectId, _projectMetadata, _memo, _msgSender());
    }

    /// @notice Creates an initial sequence of one or more rulesets for an existing project.
    /// @dev Each operation within this transaction can be done in sequence separately.
    /// @dev Only a project's owner or an operator with the `QUEUE_RULESETS` permission can launch rulesets for a project.
    /// @param _projectId The ID of the project to launch rulesets for.
    /// @param _rulesetConfigurations The ruleset configurations to queue.
    /// @param _terminalConfigurations The terminal configurations to add for the project.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return rulesetId The ID of the ruleset that was successfully launched.
    function launchRulesetsFor(
        uint256 _projectId,
        JBRulesetConfig[] calldata _rulesetConfigurations,
        JBTerminalConfig[] calldata _terminalConfigurations,
        string memory _memo
    )
        external
        virtual
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBPermissionIds.QUEUE_RULESETS)
        returns (uint256 rulesetId)
    {
        // If the project has already had rulesets, `queueRulesetsOf(...)` should be called instead
        if (rulesets.latestRulesetIdOf(_projectId) > 0) {
            revert RULESET_ALREADY_LAUNCHED();
        }

        // Set this contract as the project's controller in the directory.
        directory.setControllerOf(_projectId, IERC165(this));

        // Queue the first ruleset.
        rulesetId = _queueRulesets(_projectId, _rulesetConfigurations);

        // Configure the terminals.
        _configureTerminals(_projectId, _terminalConfigurations);

        emit LaunchRulesets(rulesetId, _projectId, _memo, _msgSender());
    }

    /// @notice Queues one or more rulesets that will take effect once the current ruleset expires. Rulesets only take effect if they are approved by the previous ruleset's approval hook.
    /// @dev Only a project's owner or an operator with the `QUEUE_RULESETS` permission from them can queue rulesets for a project.
    /// @param _projectId The ID of the project that rulesets are being queued for.
    /// @param _rulesetConfigurations The configurations of the rulesets to queue.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return rulesetId The ID of the last ruleset which was successfully queued.
    function queueRulesetsOf(
        uint256 _projectId,
        JBRulesetConfig[] calldata _rulesetConfigurations,
        string calldata _memo
    )
        external
        virtual
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBPermissionIds.QUEUE_RULESETS)
        returns (uint256 rulesetId)
    {
        // Queue the next ruleset.
        rulesetId = _queueRulesets(_projectId, _rulesetConfigurations);

        emit QueueRulesets(rulesetId, _projectId, _memo, _msgSender());
    }

    /// @notice Mint new project tokens into an account, optionally reserving a portion according to the current ruleset's reserved rate.
    /// @dev Only a project's owner, an operator with the `MINT_TOKENS` permission from them, one of the project's terminals, or its current data hook can mint a project's tokens.
    /// @dev If the ruleset has discretionary minting disabled, this function can only be called by the terminal or data hook.
    /// @param _projectId The ID of the project the tokens being minted belong to.
    /// @param _tokenCount The total number of tokens to mint, including any tokens that will be reserved.
    /// @param _beneficiary The account which will receive the (non-reserved) minted tokens.
    /// @param _memo A memo to pass along to the emitted event.
    /// @param _useReservedRate Whether to use the current ruleset's reserved rate in the minting calculations.
    /// @return beneficiaryTokenCount The number of tokens minted for the beneficiary.
    function mintTokensOf(
        uint256 _projectId,
        uint256 _tokenCount,
        address _beneficiary,
        string calldata _memo,
        bool _useReservedRate
    ) external virtual override returns (uint256 beneficiaryTokenCount) {
        // There should be tokens to mint.
        if (_tokenCount == 0) revert ZERO_TOKENS_TO_MINT();

        // Define variables that will be needed outside scoped section below.
        // Keep a reference to the reserved rate to use
        uint256 _reservedRate;

        // Scoped section prevents stack too deep. `_ruleset` only used within scope.
        {
            // Get a reference to the project's current ruleset.
            JBRuleset memory _ruleset = rulesets.currentOf(_projectId);

            // Minting limited to: project owner, operators with the `MINT_TOKENS` permission from the owner, the project's terminals, or the project's current ruleset data hook
            _requirePermissionAllowingOverride(
                projects.ownerOf(_projectId),
                _projectId,
                JBPermissionIds.MINT_TOKENS,
                directory.isTerminalOf(_projectId, IJBTerminal(_msgSender()))
                    || _msgSender() == address(_ruleset.dataHook())
            );

            // If the message sender is not a terminal or a data hook, the current ruleset must allow minting.
            if (
                !_ruleset.allowOwnerMinting()
                    && !directory.isTerminalOf(_projectId, IJBTerminal(_msgSender()))
                    && _msgSender() != address(_ruleset.dataHook())
            ) revert MINT_NOT_ALLOWED_AND_NOT_TERMINAL_HOOK();

            // Determine the reserved rate to use.
            _reservedRate = _useReservedRate ? _ruleset.reservedRate() : 0;
        }

        if (_reservedRate != JBConstants.MAX_RESERVED_RATE) {
            // The unreserved number of tokens that will be minted to the beneficiary.
            beneficiaryTokenCount = PRBMath.mulDiv(
                _tokenCount,
                JBConstants.MAX_RESERVED_RATE - _reservedRate,
                JBConstants.MAX_RESERVED_RATE
            );

            // Mint the tokens.
            tokens.mintFor(_beneficiary, _projectId, beneficiaryTokenCount);
        }

        // Add reserved tokens to the pending balance if needed
        if (_reservedRate > 0) {
            pendingReservedTokenBalanceOf[_projectId] += _tokenCount - beneficiaryTokenCount;
        }

        emit MintTokens(
            _beneficiary,
            _projectId,
            _tokenCount,
            beneficiaryTokenCount,
            _memo,
            _reservedRate,
            _msgSender()
        );
    }

    /// @notice Burns a project's tokens from a specific holder's balance.
    /// @dev Only a token holder, an operator with the `BURN_TOKENS` permission from them, or a project's terminal can burn a holder's tokens.
    /// @param _holder The account whose tokens are being burned.
    /// @param _projectId The ID of the project that the tokens being burned belong to.
    /// @param _tokenCount The number of tokens to burn.
    /// @param _memo A memo to pass along to the emitted event.
    function burnTokensOf(
        address _holder,
        uint256 _projectId,
        uint256 _tokenCount,
        string calldata _memo
    )
        external
        virtual
        override
        requirePermissionAllowingOverride(
            _holder,
            _projectId,
            JBPermissionIds.BURN_TOKENS,
            directory.isTerminalOf(_projectId, IJBTerminal(_msgSender()))
        )
    {
        // There should be tokens to burn
        if (_tokenCount == 0) revert NO_BURNABLE_TOKENS();

        // Burn the tokens.
        tokens.burnFrom(_holder, _projectId, _tokenCount);

        emit BurnTokens(_holder, _projectId, _tokenCount, _memo, _msgSender());
    }

    /// @notice Sends a project's pending reserved tokens to its reserved token splits.
    /// @dev If the project has no reserved token splits, or they don't add up to 100%, the leftover tokens are minted to the project's owner.
    /// @param _projectId The ID of the project to which the reserved tokens belong.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return The amount of reserved tokens minted and sent.
    function sendReservedTokensToSplitsOf(uint256 _projectId, string calldata _memo)
        external
        virtual
        override
        returns (uint256)
    {
        return _sendReservedTokensToSplitsOf(_projectId, _memo);
    }

    /// @notice Allows other controllers to signal to this one that a migration is expected for the specified project.
    /// @dev This controller should not yet be the project's controller.
    /// @param _from The controller being migrated from.
    /// @param _projectId The ID of the project that will be migrated to this controller.
    function receiveMigrationFrom(IERC165 _from, uint256 _projectId) external virtual override {
        _projectId; // Prevents unused var compiler and natspec complaints.
        _from; // Prevents unused var compiler and natspec complaints.

        // Copy the main metadata if relevant.
        if (
            _from.supportsInterface(type(IJBProjectMetadataRegistry).interfaceId)
                && directory.controllerOf(_projectId) == _from
        ) {
            metadataOf[_projectId] =
                IJBProjectMetadataRegistry(address(_from)).metadataOf(_projectId);
        }
    }

    /// @notice Allows a project to migrate from this controller to another one.
    /// @dev Only a project's owner or an operator with the `MIGRATE_CONTROLLER` permission from the owner can migrate it.
    /// @param _projectId The ID of the project that will be migrated from this controller.
    /// @param _to The controller the project is migrating to.
    function migrateController(uint256 _projectId, IJBMigratable _to)
        external
        virtual
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBPermissionIds.MIGRATE_CONTROLLER)
    {
        // Get a reference to the project's current ruleset.
        JBRuleset memory _ruleset = rulesets.currentOf(_projectId);

        // Migration must be allowed.
        if (!_ruleset.allowControllerMigration()) {
            revert CONTROLLER_MIGRATION_NOT_ALLOWED();
        }

        // All reserved tokens must be minted before migrating.
        if (pendingReservedTokenBalanceOf[_projectId] != 0) {
            _sendReservedTokensToSplitsOf(_projectId, "");
        }

        // Make sure the new controller is prepped for the migration.
        _to.receiveMigrationFrom(IERC165(this), _projectId);

        emit MigrateController(_projectId, _to, _msgSender());
    }

    /// @notice Set a project's metadata content.
    /// @dev Only a project's owner can set its metadata through the project's controller.
    /// @dev Frontends typically use an IPFS hash for the metadata content.
    /// @param _projectId The ID of the project to set the metadata of.
    /// @param _metadata The metadata content to set.
    function setMetadataOf(uint256 _projectId, string calldata _metadata)
        external
        override
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            JBPermissionIds.SET_PROJECT_METADATA
        )
    {
        // Set the project's new metadata content within the specified domain.
        metadataOf[_projectId] = _metadata;

        emit SetMetadata(_projectId, _metadata, _msgSender());
    }

    /// @notice Sets a project's split groups.
    /// @dev Only a project's owner or an operator with `SET_SPLITS` permission from the owner can set its splits through the project's controller.
    /// @dev The new split groups must include any currently set splits that are locked.
    /// @param _projectId The ID of the project split groups are being set for.
    /// @param _domainId The ID of the domain the split groups should be active in (this is often a `rulesetId`).
    /// @param _splitGroups An array of split groups to set.
    function setSplitGroupsOf(
        uint256 _projectId,
        uint256 _domainId,
        JBSplitGroup[] calldata _splitGroups
    )
        external
        virtual
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBPermissionIds.SET_SPLITS)
    {
        // Set splits for the group.
        splits.setSplitGroupsOf(_projectId, _domainId, _splitGroups);
    }

    /// @notice Deploys an ERC-20 token for a project. It will be used when claiming tokens (with credits).
    /// @dev Deploys a project's ERC-20 token contract.
    /// @dev Only a project's owner or an operator with `ISSUE_TOKENS` permission from the owner can deploy its token.
    /// @param _projectId The ID of the project to deploy an ERC-20 token for.
    /// @param _name The ERC-20's name.
    /// @param _symbol The ERC-20's symbol.
    /// @return token The address of the token that was deployed.
    function deployERC20For(uint256 _projectId, string calldata _name, string calldata _symbol)
        external
        virtual
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBPermissionIds.ISSUE_TOKEN)
        returns (IJBToken token)
    {
        return tokens.deployERC20For(_projectId, _name, _symbol);
    }

    /// @notice Set a project's token if not already set.
    /// @dev Only a project's owner or an operator with `SET_TOKEN` permission from the owner can set its token.
    /// @param _projectId The ID of the project to set the token of.
    /// @param _token The new token's address.
    function setTokenFor(uint256 _projectId, IJBToken _token)
        external
        virtual
        override
        requirePermission(projects.ownerOf(_projectId), _projectId, JBPermissionIds.SET_TOKEN)
    {
        tokens.setTokenFor(_projectId, _token);
    }

    /// @notice Redeem credits to claim tokens into a holder's wallet.
    /// @dev Only a credit holder or an operator with the `CLAIM_TOKENS` permission from that holder can redeem those credits to claim tokens.
    /// @param _holder The owner of the credits being redeemed.
    /// @param _projectId The ID of the project whose tokens are being claimed.
    /// @param _amount The amount of tokens to claim.
    /// @param _beneficiary The account into which the claimed tokens will go.
    function claimTokensFor(
        address _holder,
        uint256 _projectId,
        uint256 _amount,
        address _beneficiary
    )
        external
        virtual
        override
        requirePermission(_holder, _projectId, JBPermissionIds.CLAIM_TOKENS)
    {
        tokens.claimTokensFor(_holder, _projectId, _amount, _beneficiary);
    }

    /// @notice Allows a holder to transfer credits to another account.
    /// @dev Only a credit holder or an operator with the `TRANSFER_TOKENS` permission from that holder can transfer those credits.
    /// @param _holder The address to transfer credits from.
    /// @param _projectId The ID of the project whose credits are being transferred.
    /// @param _recipient The recipient of the credits.
    /// @param _amount The amount of credits to transfer.
    function transferCreditsFrom(
        address _holder,
        uint256 _projectId,
        address _recipient,
        uint256 _amount
    )
        external
        virtual
        override
        requirePermission(_holder, _projectId, JBPermissionIds.TRANSFER_TOKENS)
    {
        // Get a reference to the current ruleset for the project.
        JBRuleset memory _ruleset = rulesets.currentOf(_projectId);

        // Credit transfers must not be paused.
        if (_ruleset.pauseCreditTransfers()) revert CREDIT_TRANSFERS_PAUSED();

        tokens.transferCreditsFrom(_holder, _projectId, _recipient, _amount);
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Sends pending reserved tokens to the project's reserved token splits.
    /// @dev If the project has no reserved token splits, or they don't add up to 100%, the leftover tokens are minted to the project's owner.
    /// @param _projectId The ID of the project the reserved tokens belong to.
    /// @param _memo A memo to pass along to the emitted event.
    /// @return tokenCount The number of reserved tokens minted/sent.
    function _sendReservedTokensToSplitsOf(uint256 _projectId, string memory _memo)
        internal
        returns (uint256 tokenCount)
    {
        // Keep a reference to the token store.
        IJBTokens _tokens = tokens;

        // Get the current ruleset to read the reserved rate from.
        JBRuleset memory _ruleset = rulesets.currentOf(_projectId);

        // Get a reference to the number of tokens that need to be minted.
        tokenCount = pendingReservedTokenBalanceOf[_projectId];

        // Reset the reserved token balance
        pendingReservedTokenBalanceOf[_projectId] = 0;

        // Get a reference to the project owner.
        address _owner = projects.ownerOf(_projectId);

        // Send tokens to splits and get a reference to the leftover amount to mint after all splits have gotten their share.
        uint256 _leftoverTokenCount = tokenCount == 0
            ? 0
            : _sendTokensToSplitGroupOf(
                _projectId, _ruleset.id, JBSplitGroupIds.RESERVED_TOKENS, tokenCount
            );

        // Mint any leftover tokens to the project owner.
        if (_leftoverTokenCount > 0) {
            _tokens.mintFor(_owner, _projectId, _leftoverTokenCount);
        }

        emit SendReservedTokensToSplits(
            _ruleset.id,
            _ruleset.cycleNumber,
            _projectId,
            _owner,
            tokenCount,
            _leftoverTokenCount,
            _memo,
            _msgSender()
        );
    }

    /// @notice Send `_amount` project tokens to the specified group of splits.
    /// @dev This is used to send reserved tokens to the reserved token splits.
    /// @param _projectId The ID of the project that the split group belongs to.
    /// @param _domain The domain of the split group to send tokens to.
    /// @param _groupId The group of the splits to send the tokens between.
    /// @param _amount The total number of tokens to sent.
    /// @return leftoverAmount If the splits percents dont add up to 100%, the leftover amount is returned.
    function _sendTokensToSplitGroupOf(
        uint256 _projectId,
        uint256 _domain,
        uint256 _groupId,
        uint256 _amount
    ) internal returns (uint256 leftoverAmount) {
        // Keep a reference to the token store.
        IJBTokens _tokens = tokens;

        // Set the leftover amount to the initial amount.
        leftoverAmount = _amount;

        // Get a reference to the specified split group.
        JBSplit[] memory _splits = splits.splitsOf(_projectId, _domain, _groupId);

        // Keep a reference to the number of splits being iterated on.
        uint256 _numberOfSplits = _splits.length;

        //Transfer between all splits.
        for (uint256 _i; _i < _numberOfSplits;) {
            // Get a reference to the split being iterated on.
            JBSplit memory _split = _splits[_i];

            // Calculate the amount to send towards the split.
            uint256 _tokenCount =
                PRBMath.mulDiv(_amount, _split.percent, JBConstants.SPLITS_TOTAL_PERCENT);

            // Mints tokens for the split if needed.
            if (_tokenCount > 0) {
                _tokens.mintFor(
                    // If a `hook` is set in the splits, set it as the beneficiary.
                    // Otherwise, if a `projectId` is set in the split, set the project's owner as the beneficiary.
                    // Otherwise, if the split has a beneficiary send to the split's beneficiary.
                    // Otherwise, send to the `_msgSender()`.
                    _split.hook != IJBSplitHook(address(0))
                        ? address(_split.hook)
                        : _split.projectId != 0
                            ? projects.ownerOf(_split.projectId)
                            : _split.beneficiary != address(0) ? _split.beneficiary : _msgSender(),
                    _projectId,
                    _tokenCount
                );

                // If there's a split hook, trigger its `process` function.
                if (_split.hook != IJBSplitHook(address(0))) {
                    // Get a reference to the project's token.
                    address _token = address(_tokens.tokenOf(_projectId));

                    // Process.
                    _split.hook.process(
                        JBSplitHookPayload(_token, _tokenCount, 18, _projectId, _groupId, _split)
                    );
                }

                // Subtract from the amount to be sent to the beneficiary.
                leftoverAmount = leftoverAmount - _tokenCount;
            }

            emit SendReservedTokensToSplit(
                _projectId, _domain, _groupId, _split, _tokenCount, _msgSender()
            );

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Queues one or more ruleset configurations and stores information pertinent to the configuration.
    /// @param _projectId The ID of the project the rulesets are being queued for.
    /// @param _rulesetConfigurations Configurations for the rulesets being queued.
    /// @return rulesetId The ID of the last ruleset that was successfully queued.
    function _queueRulesets(uint256 _projectId, JBRulesetConfig[] calldata _rulesetConfigurations)
        internal
        returns (uint256 rulesetId)
    {
        // Keep a reference to the ruleset config being iterated on.
        JBRulesetConfig memory _rulesetConfig;

        // Keep a reference to the number of ruleset configurations being queued.
        uint256 _numberOfConfigurations = _rulesetConfigurations.length;

        for (uint256 _i; _i < _numberOfConfigurations;) {
            // Get a reference to the ruleset config being iterated on.
            _rulesetConfig = _rulesetConfigurations[_i];

            // Make sure the provided reserved rate is valid.
            if (_rulesetConfig.metadata.reservedRate > JBConstants.MAX_RESERVED_RATE) {
                revert INVALID_RESERVED_RATE();
            }

            // Make sure the provided redemption rate is valid.
            if (_rulesetConfig.metadata.redemptionRate > JBConstants.MAX_REDEMPTION_RATE) {
                revert INVALID_REDEMPTION_RATE();
            }

            // Make sure the provided base currency is valid.
            if (_rulesetConfig.metadata.baseCurrency > type(uint32).max) {
                revert INVALID_BASE_CURRENCY();
            }

            // Use the configuration to queue the ruleset.
            JBRuleset memory _ruleset = rulesets.queueFor(
                _projectId,
                _rulesetConfig.data,
                JBRulesetMetadataResolver.packRulesetMetadata(_rulesetConfig.metadata),
                _rulesetConfig.mustStartAtOrAfter
            );

            // Set the configuration's split groups.
            splits.setSplitGroupsOf(_projectId, _ruleset.id, _rulesetConfig.splitGroups);

            // Set the configuration's fund access limits.
            fundAccessLimits.setFundAccessLimitsFor(
                _projectId, _ruleset.id, _rulesetConfig.fundAccessLimitGroups
            );

            // Return the ruleset's ID if this is the last configuration being queued.
            if (_i == _numberOfConfigurations - 1) {
                rulesetId = _ruleset.id;
            }

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Configure terminals for use.
    /// @param _projectId The ID of the project configuring the terminals for use.
    /// @param _terminalConfigs The terminal configurations to enact.
    function _configureTerminals(uint256 _projectId, JBTerminalConfig[] calldata _terminalConfigs)
        internal
    {
        // Keep a reference to the number of terminals being configured.
        uint256 _numberOfTerminalConfigs = _terminalConfigs.length;

        // Set an array of terminals to populate.
        IJBTerminal[] memory _terminals = new IJBTerminal[](_numberOfTerminalConfigs);

        // Keep a reference to the terminal configuration being iterated on.
        JBTerminalConfig memory _terminalConfig;

        for (uint256 _i; _i < _numberOfTerminalConfigs;) {
            // Set the terminal configuration being iterated on.
            _terminalConfig = _terminalConfigs[_i];

            // Set the accounting contexts.
            _terminalConfig.terminal.addAccountingContextsFor(
                _projectId, _terminalConfig.accountingContextConfigs
            );

            // Add the terminal.
            _terminals[_i] = _terminalConfig.terminal;

            unchecked {
                ++_i;
            }
        }

        // Set the terminals in the directory.
        if (_numberOfTerminalConfigs > 0) {
            directory.setTerminalsOf(_projectId, _terminals);
        }
    }

    /// @notice Returns the sender, prefered to use over ` _msgSender()`
    /// @return _sender the sender address of this call.
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address _sender)
    {
        return ERC2771Context._msgSender();
    }

    /// @notice Returns the calldata, prefered to use over `msg.data`
    /// @return _calldata the `msg.data` of this call
    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata _calldata)
    {
        return ERC2771Context._msgData();
    }
}
