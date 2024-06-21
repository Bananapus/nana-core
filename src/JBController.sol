// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {mulDiv} from "@prb/math/src/Common.sol";

import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {JBApprovalStatus} from "./enums/JBApprovalStatus.sol";
import {IJBController} from "./interfaces/IJBController.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBDirectoryAccessControl} from "./interfaces/IJBDirectoryAccessControl.sol";
import {IJBFundAccessLimits} from "./interfaces/IJBFundAccessLimits.sol";
import {IJBMigratable} from "./interfaces/IJBMigratable.sol";
import {IJBPermissioned} from "./interfaces/IJBPermissioned.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBPriceFeed} from "./interfaces/IJBPriceFeed.sol";
import {IJBPrices} from "./interfaces/IJBPrices.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {IJBProjectUriRegistry} from "./interfaces/IJBProjectUriRegistry.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
import {IJBRulesetDataHook} from "./interfaces/IJBRulesetDataHook.sol";
import {IJBSplitHook} from "./interfaces/IJBSplitHook.sol";
import {IJBSplits} from "./interfaces/IJBSplits.sol";
import {IJBTerminal} from "./interfaces/IJBTerminal.sol";
import {IJBToken} from "./interfaces/IJBToken.sol";
import {IJBTokens} from "./interfaces/IJBTokens.sol";
import {JBConstants} from "./libraries/JBConstants.sol";
import {JBRulesetMetadataResolver} from "./libraries/JBRulesetMetadataResolver.sol";
import {JBSplitGroupIds} from "./libraries/JBSplitGroupIds.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";
import {JBRulesetConfig} from "./structs/JBRulesetConfig.sol";
import {JBRulesetMetadata} from "./structs/JBRulesetMetadata.sol";
import {JBRulesetWithMetadata} from "./structs/JBRulesetWithMetadata.sol";
import {JBSplit} from "./structs/JBSplit.sol";
import {JBSplitGroup} from "./structs/JBSplitGroup.sol";
import {JBSplitHookContext} from "./structs/JBSplitHookContext.sol";
import {JBTerminalConfig} from "./structs/JBTerminalConfig.sol";

/// @notice `JBController` coordinates rulesets and project tokens, and is the entry point for most operations related
/// to rulesets and project tokens.
contract JBController is JBPermissioned, ERC2771Context, IJBController, IJBMigratable {
    // A library that parses packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    // A library that adds default safety checks to ERC20 functionality.
    using SafeERC20 for IERC20;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error ADDING_PRICE_FEED_NOT_ALLOWED();
    error CREDIT_TRANSFERS_PAUSED();
    error RULESETS_ARRAY_EMPTY();
    error INVALID_BASE_CURRENCY();
    error INVALID_REDEMPTION_RATE();
    error INVALID_RESERVED_RATE();
    error CONTROLLER_MIGRATION_NOT_ALLOWED();
    error MINT_NOT_ALLOWED_AND_NOT_TERMINAL_OR_HOOK();
    error NO_BURNABLE_TOKENS();
    error NO_RESERVED_TOKENS();
    error RULESETS_ALREADY_LAUNCHED();
    error ZERO_TOKENS_TO_MINT();
    error RULESET_SET_TOKEN_DISABLED();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice Mints ERC-721s that represent project ownership and transfers.
    IJBProjects public immutable override PROJECTS;

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public immutable override RULESETS;

    /// @notice The contract that manages token minting and burning.
    IJBTokens public immutable override TOKENS;

    /// @notice The contract that stores splits for each project.
    IJBSplits public immutable override SPLITS;

    /// @notice A contract that stores fund access limits for each project.
    IJBFundAccessLimits public immutable override FUND_ACCESS_LIMITS;

    /// @notice A contract that stores prices for each project.
    IJBPrices public immutable override PRICES;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice A project's unrealized reserved token balance (i.e. reserved tokens which haven't been sent out to the
    /// reserved token split group yet).
    /// @custom:param projectId The ID of the project to get the pending reserved token balance of.
    mapping(uint256 projectId => uint256) public override pendingReservedTokenBalanceOf;

    /// @notice The metadata URI for each project. This is typically an IPFS hash, optionally with an `ipfs://` prefix.
    /// @custom:param projectId The ID of the project to get the metadata URI of.
    mapping(uint256 projectId => string) public override uriOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Gets the a project token's total supply, including pending reserved tokens.
    /// @param projectId The ID of the project to get the total token supply of.
    /// @return The total supply of the project's token, including pending reserved tokens.
    function totalTokenSupplyWithReservedTokensOf(uint256 projectId) external view override returns (uint256) {
        // Add the reserved tokens to the total supply.
        return TOKENS.totalSupplyOf(projectId) + pendingReservedTokenBalanceOf[projectId];
    }

    /// @notice Get the `JBRuleset` and `JBRulesetMetadata` corresponding to the specified `rulesetId`.
    /// @param projectId The ID of the project the ruleset belongs to.
    /// @return ruleset The ruleset's struct.
    /// @return metadata The ruleset's metadata.
    function getRulesetOf(
        uint256 projectId,
        uint256 rulesetId
    )
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata)
    {
        ruleset = RULESETS.getRulesetOf(projectId, rulesetId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice Gets the latest ruleset queued for a project, its approval status, and its metadata.
    /// @dev The 'latest queued ruleset' is the ruleset initialized furthest in the future (at the end of the ruleset
    /// queue).
    /// @param projectId The ID of the project to get the latest ruleset of.
    /// @return ruleset The struct for the project's latest queued ruleset.
    /// @return metadata The ruleset's metadata.
    /// @return approvalStatus The ruleset's approval status.
    function latestQueuedRulesetOf(uint256 projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata, JBApprovalStatus approvalStatus)
    {
        (ruleset, approvalStatus) = RULESETS.latestQueuedOf(projectId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice Get an array of a project's rulesets (with metadata) up to a maximum array size, sorted from latest to
    /// earliest.
    /// @param projectId The ID of the project to get the rulesets of.
    /// @param startingId The ID of the ruleset to begin with. This will be the latest ruleset in the result. If the
    /// `startingId` is 0, passed, the project's latest ruleset will be used.
    /// @param size The maximum number of rulesets to return.
    /// @return rulesets The array of rulesets with their metadata.
    function rulesetsOf(
        uint256 projectId,
        uint256 startingId,
        uint256 size
    )
        external
        view
        override
        returns (JBRulesetWithMetadata[] memory rulesets)
    {
        // Get the rulesets (without metadata).
        JBRuleset[] memory baseRulesets = RULESETS.rulesetsOf(projectId, startingId, size);

        // Keep a reference to the number of rulesets.
        uint256 numberOfRulesets = baseRulesets.length;

        // Initialize the array being returned.
        rulesets = new JBRulesetWithMetadata[](numberOfRulesets);

        // Keep a reference to the ruleset being iterated on.
        JBRuleset memory baseRuleset;

        // Populate the array with rulesets AND their metadata.
        for (uint256 i; i < numberOfRulesets; i++) {
            // Set the ruleset being iterated on.
            baseRuleset = baseRulesets[i];

            // Set the returned value.
            rulesets[i] = JBRulesetWithMetadata({ruleset: baseRuleset, metadata: baseRuleset.expandMetadata()});
        }
    }

    /// @notice A project's currently active ruleset and its metadata.
    /// @param projectId The ID of the project to get the current ruleset of.
    /// @return ruleset The current ruleset's struct.
    /// @return metadata The current ruleset's metadata.
    function currentRulesetOf(uint256 projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata)
    {
        ruleset = RULESETS.currentOf(projectId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice A project's next ruleset along with its metadata.
    /// @dev If an upcoming ruleset isn't found, returns an empty ruleset with all properties set to 0.
    /// @param projectId The ID of the project to get the next ruleset of.
    /// @return ruleset The upcoming ruleset's struct.
    /// @return metadata The upcoming ruleset's metadata.
    function upcomingRulesetOf(uint256 projectId)
        external
        view
        override
        returns (JBRuleset memory ruleset, JBRulesetMetadata memory metadata)
    {
        ruleset = RULESETS.upcomingOf(projectId);
        metadata = ruleset.expandMetadata();
    }

    /// @notice Check whether the project's terminals can currently be set.
    /// @param projectId The ID of the project to check.
    /// @return A `bool` which is true if the project allows terminals to be set.
    function setTerminalsAllowed(uint256 projectId) external view returns (bool) {
        return RULESETS.currentOf(projectId).expandMetadata().allowSetTerminals;
    }

    /// @notice Check whether the project's controller can currently be set.
    /// @param projectId The ID of the project to check.
    /// @return A `bool` which is true if the project allows controllers to be set.
    function setControllerAllowed(uint256 projectId) external view returns (bool) {
        return RULESETS.currentOf(projectId).expandMetadata().allowSetController;
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates whether this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IJBController).interfaceId || interfaceId == type(IJBProjectUriRegistry).interfaceId
            || interfaceId == type(IJBDirectoryAccessControl).interfaceId || interfaceId == type(IJBMigratable).interfaceId
            || interfaceId == type(IJBPermissioned).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    //*********************************************************************//
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param permissions A contract storing permissions.
    /// @param projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param directory A contract storing directories of terminals and controllers for each project.
    /// @param rulesets A contract storing and managing project rulesets.
    /// @param tokens A contract that manages token minting and burning.
    /// @param splits A contract that stores splits for each project.
    /// @param fundAccessLimits A contract that stores fund access limits for each project.
    /// @param prices A contract that stores prices for each project.
    constructor(
        IJBPermissions permissions,
        IJBProjects projects,
        IJBDirectory directory,
        IJBRulesets rulesets,
        IJBTokens tokens,
        IJBSplits splits,
        IJBFundAccessLimits fundAccessLimits,
        IJBPrices prices,
        address trustedForwarder
    )
        JBPermissioned(permissions)
        ERC2771Context(trustedForwarder)
    {
        PROJECTS = projects;
        DIRECTORY = directory;
        RULESETS = rulesets;
        TOKENS = tokens;
        SPLITS = splits;
        FUND_ACCESS_LIMITS = fundAccessLimits;
        PRICES = prices;
    }

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
    //*********************************************************************//

    /// @notice Creates a project.
    /// @dev This will mint the project's ERC-721 to the `owner`'s address, queue the specified rulesets, and set up the
    /// specified splits and terminals. Each operation within this transaction can be done in sequence separately.
    /// @dev Anyone can deploy a project to any `owner`'s address.
    /// @param owner The project's owner. The project ERC-721 will be minted to this address.
    /// @param projectUri The project's metadata URI. This is typically an IPFS hash, optionally with the `ipfs://`
    /// prefix. This can be updated by the project's owner.
    /// @param rulesetConfigurations The rulesets to queue.
    /// @param terminalConfigurations The terminals to set up for the project.
    /// @param memo A memo to pass along to the emitted event.
    /// @return projectId The project's ID.
    function launchProjectFor(
        address owner,
        string calldata projectUri,
        JBRulesetConfig[] calldata rulesetConfigurations,
        JBTerminalConfig[] calldata terminalConfigurations,
        string memory memo
    )
        external
        virtual
        override
        returns (uint256 projectId)
    {
        // Mint the project ERC-721 into the owner's wallet.
        projectId = PROJECTS.createFor(owner);

        // If provided, set the project's metadata URI.
        if (bytes(projectUri).length > 0) {
            uriOf[projectId] = projectUri;
        }

        // Set this contract as the project's controller in the directory.
        DIRECTORY.setControllerOf(projectId, IERC165(this));

        // Queue the rulesets.
        uint256 rulesetId = _queueRulesets(projectId, rulesetConfigurations);

        // Configure the terminals.
        _configureTerminals(projectId, terminalConfigurations);

        emit LaunchProject(rulesetId, projectId, projectUri, memo, _msgSender());
    }

    /// @notice Queue a project's initial rulesets and set up terminals for it. Projects which already have rulesets
    /// should use `queueRulesetsOf(...)`.
    /// @dev Each operation within this transaction can be done in sequence separately.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `QUEUE_RULESETS`.
    /// @param projectId The ID of the project to launch rulesets for.
    /// @param rulesetConfigurations The rulesets to queue.
    /// @param terminalConfigurations The terminals to set up.
    /// @param memo A memo to pass along to the emitted event.
    /// @return rulesetId The ID of the last successfully queued ruleset.
    function launchRulesetsFor(
        uint256 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations,
        JBTerminalConfig[] calldata terminalConfigurations,
        string memory memo
    )
        external
        virtual
        override
        returns (uint256 rulesetId)
    {
        if (rulesetConfigurations.length == 0) revert RULESETS_ARRAY_EMPTY();

        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.QUEUE_RULESETS
        });

        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_TERMINALS
        });

        // If the project has already had rulesets, use `queueRulesetsOf(...)` instead.
        if (RULESETS.latestRulesetIdOf(projectId) > 0) {
            revert RULESETS_ALREADY_LAUNCHED();
        }

        // Set this contract as the project's controller in the directory.
        DIRECTORY.setControllerOf(projectId, IERC165(this));

        // Queue the first ruleset.
        rulesetId = _queueRulesets(projectId, rulesetConfigurations);

        // Configure the terminals.
        _configureTerminals(projectId, terminalConfigurations);

        emit LaunchRulesets(rulesetId, projectId, memo, _msgSender());
    }

    /// @notice Add one or more rulesets to the end of a project's ruleset queue. Rulesets take effect after the
    /// previous ruleset in the queue ends, and only if they are approved by the previous ruleset's approval hook.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `QUEUE_RULESETS`.
    /// @param projectId The ID of the project to queue rulesets for.
    /// @param rulesetConfigurations The rulesets to queue.
    /// @param memo A memo to pass along to the emitted event.
    /// @return rulesetId The ID of the last ruleset which was successfully queued.
    function queueRulesetsOf(
        uint256 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations,
        string calldata memo
    )
        external
        virtual
        override
        returns (uint256 rulesetId)
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.QUEUE_RULESETS
        });

        // Queue the rulesets.
        rulesetId = _queueRulesets(projectId, rulesetConfigurations);

        emit QueueRulesets(rulesetId, projectId, memo, _msgSender());
    }

    /// @notice Add new project tokens or credits to the specified beneficiary's balance. Optionally, reserve a portion
    /// according to the ruleset's reserved rate.
    /// @dev Can only be called by the project's owner, an address with the owner's permission to `MINT_TOKENS`, one of
    /// the project's terminals, or the project's data hook.
    /// @dev If the ruleset's metadata has `allowOwnerMinting` set to `false`, this function can only be called by the
    /// project's terminals or data hook.
    /// @param projectId The ID of the project whose tokens are being minted.
    /// @param tokenCount The number of tokens to mint, including any reserved tokens.
    /// @param beneficiary The address which will receive the (non-reserved) tokens.
    /// @param memo A memo to pass along to the emitted event.
    /// @param useReservedRate Whether to apply the ruleset's reserved rate.
    /// @return beneficiaryTokenCount The number of tokens minted for the `beneficiary`.
    function mintTokensOf(
        uint256 projectId,
        uint256 tokenCount,
        address beneficiary,
        string calldata memo,
        bool useReservedRate
    )
        external
        virtual
        override
        returns (uint256 beneficiaryTokenCount)
    {
        // There should be tokens to mint.
        if (tokenCount == 0) revert ZERO_TOKENS_TO_MINT();

        // Keep a reference to the reserved rate.
        uint256 reservedRate;

        // Get a reference to the project's ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Minting is restricted to: the project's owner, addresses with permission to `MINT_TOKENS`, the project's
        // terminals, and the project's data hook.
        _requirePermissionAllowingOverrideFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.MINT_TOKENS,
            alsoGrantAccessIf: DIRECTORY.isTerminalOf(projectId, IJBTerminal(_msgSender()))
                || _msgSender() == ruleset.dataHook()
                || (
                    ruleset.dataHook() != address(0)
                        && IJBRulesetDataHook(ruleset.dataHook()).hasMintPermissionFor(projectId, _msgSender())
                )
        });

        // If the message sender is not the project's terminal or data hook, the ruleset must have `allowOwnerMinting`
        // set to `true`.
        if (
            ruleset.id != 0 && !ruleset.allowOwnerMinting()
                && !DIRECTORY.isTerminalOf(projectId, IJBTerminal(_msgSender()))
                && _msgSender() != address(ruleset.dataHook())
                && (
                    ruleset.dataHook() == address(0)
                        || !IJBRulesetDataHook(ruleset.dataHook()).hasMintPermissionFor(projectId, _msgSender())
                )
        ) revert MINT_NOT_ALLOWED_AND_NOT_TERMINAL_OR_HOOK();

        // Determine the reserved rate to use.
        reservedRate = useReservedRate ? ruleset.reservedRate() : 0;

        if (reservedRate != JBConstants.MAX_RESERVED_RATE) {
            // Calculate the number of (non-reserved) tokens that will be minted to the beneficiary.
            beneficiaryTokenCount =
                mulDiv(tokenCount, JBConstants.MAX_RESERVED_RATE - reservedRate, JBConstants.MAX_RESERVED_RATE);

            // Mint the tokens.
            TOKENS.mintFor(beneficiary, projectId, beneficiaryTokenCount);
        }

        // Add any reserved tokens to the pending reserved token balance.
        if (reservedRate > 0) {
            pendingReservedTokenBalanceOf[projectId] += tokenCount - beneficiaryTokenCount;
        }

        emit MintTokens(beneficiary, projectId, tokenCount, beneficiaryTokenCount, memo, reservedRate, _msgSender());
    }

    /// @notice Burns a project's tokens or credits from the specific holder's balance.
    /// @dev Can only be called by the holder, an address with the holder's permission to `BURN_TOKENS`, or a project's
    /// terminal.
    /// @param holder The address whose tokens are being burned.
    /// @param projectId The ID of the project whose tokens are being burned.
    /// @param tokenCount The number of tokens to burn.
    /// @param memo A memo to pass along to the emitted event.
    function burnTokensOf(
        address holder,
        uint256 projectId,
        uint256 tokenCount,
        string calldata memo
    )
        external
        virtual
        override
    {
        // Enforce permissions.
        _requirePermissionAllowingOverrideFrom({
            account: holder,
            projectId: projectId,
            permissionId: JBPermissionIds.BURN_TOKENS,
            alsoGrantAccessIf: DIRECTORY.isTerminalOf(projectId, IJBTerminal(_msgSender()))
        });

        // There must be tokens to burn.
        if (tokenCount == 0) revert NO_BURNABLE_TOKENS();

        // Burn the tokens.
        TOKENS.burnFrom(holder, projectId, tokenCount);

        emit BurnTokens(holder, projectId, tokenCount, memo, _msgSender());
    }

    /// @notice Sends a project's pending reserved tokens to its reserved token splits.
    /// @dev If the project has no reserved token splits, or if they don't add up to 100%, leftover tokens are sent to
    /// the project's owner.
    /// @param projectId The ID of the project to send reserved tokens for.
    /// @return The amount of reserved tokens minted and sent.
    function sendReservedTokensToSplitsOf(uint256 projectId) external virtual override returns (uint256) {
        return _sendReservedTokensToSplitsOf(projectId);
    }

    /// @notice Prepares this controller to receive a project being migrated from another controller.
    /// @dev This controller should not be the project's controller yet.
    /// @param from The controller being migrated from.
    /// @param projectId The ID of the project that will migrate to this controller.
    function receiveMigrationFrom(IERC165 from, uint256 projectId) external virtual override {
        // If the sending controller is an `IJBProjectUriRegistry`, copy the project's metadata URI.
        if (
            from.supportsInterface(type(IJBProjectUriRegistry).interfaceId) && DIRECTORY.controllerOf(projectId) == from
        ) {
            uriOf[projectId] = IJBProjectUriRegistry(address(from)).uriOf(projectId);
        }
    }

    /// @notice Migrate a project from this controller to another one.
    /// @dev Can only be called by the directory.
    /// @param projectId The ID of the project to migrate.
    /// @param to The controller to migrate the project to.
    function migrate(uint256 projectId, IERC165 to) external virtual override {
        // Make sure this is being called by the directory.
        if (msg.sender != address(DIRECTORY)) revert UNAUTHORIZED();

        // Mint any pending reserved tokens before migrating.
        if (pendingReservedTokenBalanceOf[projectId] != 0) {
            _sendReservedTokensToSplitsOf(projectId);
        }

        // Prepare the new controller to receive the project.
        if (to.supportsInterface(type(IJBMigratable).interfaceId)) {
            IJBMigratable(address(to)).receiveMigrationFrom(IERC165(this), projectId);
        }

        emit Migrate(projectId, to, msg.sender);
    }

    /// @notice Set a project's metadata URI.
    /// @dev This is typically an IPFS hash, optionally with an `ipfs://` prefix.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to
    /// `SET_PROJECT_METADATA`.
    /// @param projectId The ID of the project to set the metadata URI of.
    /// @param metadata The metadata URI to set.
    function setUriOf(uint256 projectId, string calldata metadata) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_PROJECT_METADATA
        });

        // Set the project's metadata URI.
        uriOf[projectId] = metadata;

        emit SetMetadata(projectId, metadata, _msgSender());
    }

    /// @notice Sets a project's split groups. The new split groups must include any current splits which are locked.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `SET_SPLIT_GROUPS`.
    /// @param projectId The ID of the project to set the split groups of.
    /// @param rulesetId The ID of the ruleset the split groups should be active in. Use a `rulesetId` of 0 to set the
    /// default split groups, which are used when a ruleset has no splits set. If there are no default splits and no
    /// splits are set, all splits are sent to the project's owner.
    /// @param splitGroups An array of split groups to set.
    function setSplitGroupsOf(
        uint256 projectId,
        uint256 rulesetId,
        JBSplitGroup[] calldata splitGroups
    )
        external
        virtual
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_SPLIT_GROUPS
        });

        // Set the split groups.
        SPLITS.setSplitGroupsOf(projectId, rulesetId, splitGroups);
    }

    /// @notice Deploys an ERC-20 token for a project. It will be used when claiming tokens (with credits).
    /// @dev Deploys the project's ERC-20 contract.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `DEPLOY_ERC20`.
    /// @param projectId The ID of the project to deploy the ERC-20 for.
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
        virtual
        override
        returns (IJBToken token)
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.DEPLOY_ERC20
        });

        if (salt != bytes32(0)) salt = keccak256(abi.encodePacked(_msgSender(), salt));

        return TOKENS.deployERC20For(projectId, name, symbol, salt);
    }

    /// @notice Set a project's token. If the project's token is already set, this will revert.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `SET_TOKEN`.
    /// @param projectId The ID of the project to set the token of.
    /// @param token The new token's address.
    function setTokenFor(uint256 projectId, IJBToken token) external virtual override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_TOKEN
        });

        // Get a reference to the current ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // If there's no current ruleset, get a reference to the upcoming one.
        if (ruleset.id == 0) ruleset = RULESETS.upcomingOf(projectId);

        // If owner minting is disabled for the ruleset, the owner cannot change the token.
        if (!ruleset.allowSetCustomToken()) revert RULESET_SET_TOKEN_DISABLED();

        TOKENS.setTokenFor(projectId, token);
    }

    /// @notice Redeem credits to claim tokens into a `beneficiary`'s account.
    /// @dev Can only be called by the credit holder or an address with the holder's permission to `CLAIM_TOKENS`.
    /// @param holder The address to redeem credits from.
    /// @param projectId The ID of the project whose tokens are being claimed.
    /// @param amount The amount of tokens to claim.
    /// @param beneficiary The account the claimed tokens will go to.
    function claimTokensFor(
        address holder,
        uint256 projectId,
        uint256 amount,
        address beneficiary
    )
        external
        virtual
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({account: holder, projectId: projectId, permissionId: JBPermissionIds.CLAIM_TOKENS});

        TOKENS.claimTokensFor(holder, projectId, amount, beneficiary);
    }

    /// @notice Allows a credit holder to transfer credits to another address.
    /// @dev Can only be called by the credit holder or an address with the holder's permission to `TRANSFER_CREDITS`.
    /// @param holder The address to transfer credits from.
    /// @param projectId The ID of the project whose credits are being transferred.
    /// @param recipient The address to transfer credits to.
    /// @param amount The amount of credits to transfer.
    function transferCreditsFrom(
        address holder,
        uint256 projectId,
        address recipient,
        uint256 amount
    )
        external
        virtual
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({account: holder, projectId: projectId, permissionId: JBPermissionIds.TRANSFER_CREDITS});

        // Get a reference to the project's ruleset.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Credit transfers must not be paused.
        if (ruleset.pauseCreditTransfers()) revert CREDIT_TRANSFERS_PAUSED();

        TOKENS.transferCreditsFrom(holder, projectId, recipient, amount);
    }

    /// @notice Add a price feed to a project.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `ADD_PRICE_FEED`.
    /// @param projectId The ID of the project having a feed added.
    /// @param pricingCurrency The currency the feed's resulting price is in terms of.
    /// @param unitCurrency The currency being priced by the feed.
    /// @param feed The price feed being added.
    function addPriceFeed(
        uint256 projectId,
        uint256 pricingCurrency,
        uint256 unitCurrency,
        IJBPriceFeed feed
    )
        external
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.ADD_PRICE_FEED
        });

        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Make sure adding a price feed is allowed.
        if (!ruleset.allowAddPriceFeed()) revert ADDING_PRICE_FEED_NOT_ALLOWED();

        PRICES.addPriceFeedFor(projectId, pricingCurrency, unitCurrency, feed);
    }

    /// @notice When a project receives reserved tokens, if it has a terminal for the token, this is used to pay the
    /// terminal.
    /// @dev Can only be called by this controller.
    /// @param terminal The terminal to pay.
    /// @param projectId The ID of the project being paid.
    /// @param token The token being paid with.
    /// @param splitAmount The amount of tokens being paid.
    /// @param beneficiary The payment's beneficiary.
    /// @param metadata The pay metadata sent to the terminal.
    function payReservedTokenToTerminal(
        IJBTerminal terminal,
        uint256 projectId,
        IJBToken token,
        uint256 splitAmount,
        address beneficiary,
        bytes calldata metadata
    )
        external
    {
        // Can only be called by this contract.
        require(msg.sender == address(this));

        // Approve the tokens being paid.
        IERC20(address(token)).forceApprove(address(terminal), splitAmount);

        // slither-disable-next-line unused-return
        terminal.pay({
            projectId: projectId,
            token: address(token),
            amount: splitAmount,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: metadata
        });

        // Make sure that the terminal received the tokens.
        assert(IERC20(address(token)).allowance(address(this), address(terminal)) == 0);
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice The message's sender. Preferred to use over `msg.sender`.
    /// @return sender The address which sent this call.
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice The calldata. Preferred to use over `msg.data`.
    /// @return calldata The `msg.data` of this call.
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @dev `ERC-2771` specifies the context as being a single address (20 bytes).
    function _contextSuffixLength() internal view virtual override(ERC2771Context, Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Sends pending reserved tokens to the project's reserved token splits.
    /// @dev If the project has no reserved token splits, or if they don't add up to 100%, leftover tokens are sent to
    /// the project's owner.
    /// @param projectId The ID of the project to send reserved tokens for.
    /// @return tokenCount The amount of reserved tokens minted and sent.
    function _sendReservedTokensToSplitsOf(uint256 projectId) internal returns (uint256 tokenCount) {
        // Get a reference to the number of tokens that need to be minted.
        tokenCount = pendingReservedTokenBalanceOf[projectId];

        // Revert if there are no pending reserved tokens
        if (tokenCount == 0) revert NO_RESERVED_TOKENS();

        // Get the ruleset to read the reserved rate from.
        JBRuleset memory ruleset = RULESETS.currentOf(projectId);

        // Reset the pending reserved token balance.
        pendingReservedTokenBalanceOf[projectId] = 0;

        // Get a reference to the project's owner.
        address owner = PROJECTS.ownerOf(projectId);

        // Send reserved tokens to splits and get a reference to the amount left after the splits have all been paid.
        uint256 leftoverTokenCount = tokenCount == 0
            ? 0
            : _sendTokensToSplitGroupOf(projectId, ruleset.id, JBSplitGroupIds.RESERVED_TOKENS, tokenCount);

        // Mint any leftover tokens to the project owner.
        if (leftoverTokenCount > 0) {
            TOKENS.mintFor(owner, projectId, leftoverTokenCount);
        }

        emit SendReservedTokensToSplits(
            ruleset.id, ruleset.cycleNumber, projectId, owner, tokenCount, leftoverTokenCount, _msgSender()
        );
    }

    /// @notice Send project tokens to a split group.
    /// @dev This is used to send reserved tokens to the reserved token split group.
    /// @param projectId The ID of the project the splits belong to.
    /// @param rulesetId The ID of the split group's ruleset.
    /// @param groupId The ID of the split group.
    /// @param amount The number of tokens to send.
    /// @return leftoverAmount If the split percents don't add up to 100%, the leftover amount is returned.
    function _sendTokensToSplitGroupOf(
        uint256 projectId,
        uint256 rulesetId,
        uint256 groupId,
        uint256 amount
    )
        internal
        returns (uint256 leftoverAmount)
    {
        // Set the leftover amount to the initial amount.
        leftoverAmount = amount;

        // Get a reference to the split group.
        JBSplit[] memory splits = SPLITS.splitsOf(projectId, rulesetId, groupId);

        // Keep a reference to the number of splits being iterated on.
        uint256 numberOfSplits = splits.length;

        // Send the tokens to the splits.
        for (uint256 i; i < numberOfSplits; i++) {
            // Get a reference to the split being iterated on.
            JBSplit memory split = splits[i];

            // Calculate the amount to send to the split.
            uint256 splitAmount = mulDiv(amount, split.percent, JBConstants.SPLITS_TOTAL_PERCENT);

            // Mints tokens for the split if needed.
            if (splitAmount > 0) {
                // 1. If the split has a `hook`, call the hook's `processSplitWith` function.
                // 2. Otherwise, if the split has a `projectId`, try to pay the project using the split's `beneficiary`,
                // or the `_msgSender()` if the split has no beneficiary.
                // 3. Otherwise, if the split has a beneficiary, send the tokens to the split's beneficiary.
                // 4. Otherwise, send the tokens to the `_msgSender()`.

                // If the split has a hook, call its `processSplitWith` function.
                if (split.hook != IJBSplitHook(address(0))) {
                    // Mint the tokens for the split hook.
                    TOKENS.mintFor(address(split.hook), projectId, splitAmount);

                    // Get a reference to the project token address. If the project doesn't have a token, this will
                    // return the 0 address.
                    IJBToken token = TOKENS.tokenOf(projectId);

                    split.hook.processSplitWith(
                        JBSplitHookContext({
                            token: address(token),
                            amount: splitAmount,
                            decimals: 18, // Hard-coded in `JBTokens`.
                            projectId: projectId,
                            groupId: groupId,
                            split: split
                        })
                    );
                    // If the split has a project ID, try to pay the project. If that fails, pay the beneficiary.
                } else {
                    // Pay the project using the split's beneficiary if one was provided. Otherwise, use the message
                    // sender.
                    address beneficiary = split.beneficiary != address(0) ? split.beneficiary : _msgSender();

                    if (split.projectId != 0) {
                        // Get a reference to the project's token address. If the project doesn't have a token, this
                        // will return the 0 address.
                        IJBToken token = TOKENS.tokenOf(projectId);

                        // Get a reference to the receiving project's primary payment terminal for the token.
                        IJBTerminal terminal = token == IJBToken(address(0))
                            ? IJBTerminal(address(0))
                            : DIRECTORY.primaryTerminalOf(split.projectId, address(token));

                        // If the project doesn't have a token, or if the receiving project doesn't have a terminal
                        // which accepts the token, send the tokens to the beneficiary.
                        if (address(token) == address(0) || address(terminal) == address(0)) {
                            // Mint the tokens to the beneficiary.
                            TOKENS.mintFor(beneficiary, projectId, splitAmount);
                        } else {
                            // Mint the tokens to this contract.
                            TOKENS.mintFor(address(this), projectId, splitAmount);

                            // Use the `projectId` in the pay metadata.
                            bytes memory metadata = bytes(abi.encodePacked(projectId));

                            // Try to fulfill the payment.
                            try this.payReservedTokenToTerminal({
                                projectId: split.projectId,
                                terminal: terminal,
                                token: token,
                                splitAmount: splitAmount,
                                beneficiary: beneficiary,
                                metadata: metadata
                            }) {} catch (bytes memory reason) {
                                // If it fails, transfer the tokens from this contract to the beneficiary.
                                IERC20(address(token)).safeTransfer(beneficiary, splitAmount);
                                emit ReservedDistributionReverted(projectId, split, splitAmount, reason, _msgSender());
                            }
                        }
                    } else {
                        // If the split has no project ID, mint the tokens to the beneficiary.
                        TOKENS.mintFor(beneficiary, projectId, splitAmount);
                    }
                }

                // Subtract the amount sent from the leftover.
                leftoverAmount = leftoverAmount - splitAmount;
            }

            emit SendReservedTokensToSplit(projectId, rulesetId, groupId, split, splitAmount, _msgSender());
        }
    }

    /// @notice Queues one or more rulesets and stores information pertinent to the configuration.
    /// @param projectId The ID of the project to queue rulesets for.
    /// @param rulesetConfigurations The rulesets being queued.
    /// @return rulesetId The ID of the last ruleset that was successfully queued.
    function _queueRulesets(
        uint256 projectId,
        JBRulesetConfig[] calldata rulesetConfigurations
    )
        internal
        returns (uint256 rulesetId)
    {
        // Keep a reference to the number of ruleset configurations being queued.
        uint256 numberOfConfigurations = rulesetConfigurations.length;

        // Keep a reference to the ruleset config being iterated on.
        JBRulesetConfig memory rulesetConfig;

        for (uint256 i; i < numberOfConfigurations; i++) {
            // Get a reference to the ruleset config being iterated on.
            rulesetConfig = rulesetConfigurations[i];

            // Make sure its reserved rate is valid.
            if (rulesetConfig.metadata.reservedRate > JBConstants.MAX_RESERVED_RATE) {
                revert INVALID_RESERVED_RATE();
            }

            // Make sure its redemption rate is valid.
            if (rulesetConfig.metadata.redemptionRate > JBConstants.MAX_REDEMPTION_RATE) {
                revert INVALID_REDEMPTION_RATE();
            }

            // Make sure its base currency is valid.
            if (rulesetConfig.metadata.baseCurrency > type(uint32).max) {
                revert INVALID_BASE_CURRENCY();
            }

            // Queue its ruleset.
            JBRuleset memory ruleset = RULESETS.queueFor({
                projectId: projectId,
                duration: rulesetConfig.duration,
                weight: rulesetConfig.weight,
                decayRate: rulesetConfig.decayRate,
                approvalHook: rulesetConfig.approvalHook,
                metadata: JBRulesetMetadataResolver.packRulesetMetadata(rulesetConfig.metadata),
                mustStartAtOrAfter: rulesetConfig.mustStartAtOrAfter
            });

            // Set its split groups.
            SPLITS.setSplitGroupsOf(projectId, ruleset.id, rulesetConfig.splitGroups);

            // Set its fund access limits.
            FUND_ACCESS_LIMITS.setFundAccessLimitsFor(projectId, ruleset.id, rulesetConfig.fundAccessLimitGroups);

            // If this is the last configuration being queued, return the ruleset's ID.
            if (i == numberOfConfigurations - 1) {
                rulesetId = ruleset.id;
            }
        }
    }

    /// @notice Set up a project's terminals.
    /// @param projectId The ID of the project to set up terminals for.
    /// @param terminalConfigs The terminals to set up.
    function _configureTerminals(uint256 projectId, JBTerminalConfig[] calldata terminalConfigs) internal {
        // Keep a reference to the number of terminals being configured.
        uint256 numberOfTerminalConfigs = terminalConfigs.length;

        // Initialize an array of terminals to populate.
        IJBTerminal[] memory terminals = new IJBTerminal[](numberOfTerminalConfigs);

        // Keep a reference to the terminal configuration being iterated on.
        JBTerminalConfig memory terminalConfig;

        for (uint256 i; i < numberOfTerminalConfigs; i++) {
            // Set the terminal configuration being iterated on.
            terminalConfig = terminalConfigs[i];

            // Add the accounting contexts for the specified tokens.
            terminalConfig.terminal.addAccountingContextsFor(projectId, terminalConfig.accountingContextsToAccept);

            // Add the terminal.
            terminals[i] = terminalConfig.terminal;
        }

        // Set the terminals in the directory.
        if (numberOfTerminalConfigs > 0) {
            DIRECTORY.setTerminalsOf(projectId, terminals);
        }
    }
}
