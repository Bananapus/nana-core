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
import {IJBRulesetDataHook} from "./interfaces/IJBRulesetDataHook.sol";
import {IJBRulesets} from "./interfaces/IJBRulesets.sol";
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

    error JBController_AddingPriceFeedNotAllowed();
    error JBController_CreditTransfersPaused();
    error JBController_InvalidCashOutTaxRate(uint256 rate, uint256 limit);
    error JBController_InvalidReservedPercent(uint256 percent, uint256 limit);
    error JBController_MintNotAllowedAndNotTerminalOrHook();
    error JBController_NoReservedTokens();
    error JBController_OnlyFromTargetTerminal(address sender, address targetTerminal);
    error JBController_OnlyDirectory(address sender, IJBDirectory directory);
    error JBController_RulesetsAlreadyLaunched();
    error JBController_RulesetsArrayEmpty();
    error JBController_RulesetSetTokenNotAllowed();
    error JBController_ZeroTokensToBurn();
    error JBController_ZeroTokensToMint();

    //*********************************************************************//
    // --------------- public immutable stored properties ---------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    /// @notice A contract that stores fund access limits for each project.
    IJBFundAccessLimits public immutable override FUND_ACCESS_LIMITS;

    /// @notice A contract that stores prices for each project.
    IJBPrices public immutable override PRICES;

    /// @notice Mints ERC-721s that represent project ownership and transfers.
    IJBProjects public immutable override PROJECTS;

    /// @notice The contract storing and managing project rulesets.
    IJBRulesets public immutable override RULESETS;

    /// @notice The contract that stores splits for each project.
    IJBSplits public immutable override SPLITS;

    /// @notice The contract that manages token minting and burning.
    IJBTokens public immutable override TOKENS;

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
    // ---------------------------- constructor -------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    /// @param fundAccessLimits A contract that stores fund access limits for each project.
    /// @param permissions A contract storing permissions.
    /// @param prices A contract that stores prices for each project.
    /// @param projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param rulesets A contract storing and managing project rulesets.
    /// @param splits A contract that stores splits for each project.
    /// @param tokens A contract that manages token minting and burning.
    constructor(
        IJBDirectory directory,
        IJBFundAccessLimits fundAccessLimits,
        IJBPermissions permissions,
        IJBPrices prices,
        IJBProjects projects,
        IJBRulesets rulesets,
        IJBSplits splits,
        IJBTokens tokens,
        address trustedForwarder
    )
        JBPermissioned(permissions)
        ERC2771Context(trustedForwarder)
    {
        DIRECTORY = directory;
        FUND_ACCESS_LIMITS = fundAccessLimits;
        PRICES = prices;
        PROJECTS = projects;
        RULESETS = rulesets;
        SPLITS = splits;
        TOKENS = tokens;
    }

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice Get an array of a project's rulesets (with metadata) up to a maximum array size, sorted from latest to
    /// earliest.
    /// @param projectId The ID of the project to get the rulesets of.
    /// @param startingId The ID of the ruleset to begin with. This will be the latest ruleset in the result. If the
    /// `startingId` is 0, passed, the project's latest ruleset will be used.
    /// @param size The maximum number of rulesets to return.
    /// @return rulesets The array of rulesets with their metadata.
    function allRulesetsOf(
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
        JBRuleset[] memory baseRulesets = RULESETS.allOf(projectId, startingId, size);

        // Keep a reference to the number of rulesets.
        uint256 numberOfRulesets = baseRulesets.length;

        // Initialize the array being returned.
        rulesets = new JBRulesetWithMetadata[](numberOfRulesets);

        // Populate the array with rulesets AND their metadata.
        for (uint256 i; i < numberOfRulesets; i++) {
            // Set the ruleset being iterated on.
            JBRuleset memory baseRuleset = baseRulesets[i];

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
        ruleset = _currentRulesetOf(projectId);
        metadata = ruleset.expandMetadata();
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

    /// @notice Check whether the project's terminals can currently be set.
    /// @param projectId The ID of the project to check.
    /// @return A `bool` which is true if the project allows terminals to be set.
    function setTerminalsAllowed(uint256 projectId) external view returns (bool) {
        return _currentRulesetOf(projectId).expandMetadata().allowSetTerminals;
    }

    /// @notice Check whether the project's controller can currently be set.
    /// @param projectId The ID of the project to check.
    /// @return A `bool` which is true if the project allows controllers to be set.
    function setControllerAllowed(uint256 projectId) external view returns (bool) {
        return _currentRulesetOf(projectId).expandMetadata().allowSetController;
    }

    /// @notice Gets the a project token's total supply, including pending reserved tokens.
    /// @param projectId The ID of the project to get the total token supply of.
    /// @return The total supply of the project's token, including pending reserved tokens.
    function totalTokenSupplyWithReservedTokensOf(uint256 projectId) external view override returns (uint256) {
        // Add the reserved tokens to the total supply.
        return TOKENS.totalSupplyOf(projectId) + pendingReservedTokenBalanceOf[projectId];
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
        ruleset = _upcomingRulesetOf(projectId);
        metadata = ruleset.expandMetadata();
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Indicates whether this contract adheres to the specified interface.
    /// @dev See {IERC165-supportsInterface}.
    /// @param interfaceId The ID of the interface to check for adherence to.
    /// @return A flag indicating if the provided interface ID is supported.
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IJBController).interfaceId || interfaceId == type(IJBProjectUriRegistry).interfaceId
            || interfaceId == type(IJBDirectoryAccessControl).interfaceId || interfaceId == type(IJBMigratable).interfaceId
            || interfaceId == type(IJBPermissioned).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    //*********************************************************************//
    // -------------------------- internal views ------------------------- //
    //*********************************************************************//

    /// @dev `ERC-2771` specifies the context as being a single address (20 bytes).
    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
        return super._contextSuffixLength();
    }

    /// @notice The project's current ruleset.
    /// @param projectId The ID of the project to check.
    /// @return The project's current ruleset.
    function _currentRulesetOf(uint256 projectId) internal view returns (JBRuleset memory) {
        return RULESETS.currentOf(projectId);
    }

    /// @notice Indicates whether the provided address is a terminal for the project.
    /// @param projectId The ID of the project to check.
    /// @param terminal The address to check.
    /// @return A flag indicating if the provided address is a terminal for the project.
    function _isTerminalOf(uint256 projectId, address terminal) internal view returns (bool) {
        return DIRECTORY.isTerminalOf(projectId, IJBTerminal(terminal));
    }

    /// @notice Indicates whether the provided address has mint permission for the project byway of the data hook.
    /// @param projectId The ID of the project to check.
    /// @param ruleset The ruleset to check.
    /// @param addrs The address to check.
    /// @return A flag indicating if the provided address has mint permission for the project.
    function _hasDataHookMintPermissionFor(
        uint256 projectId,
        JBRuleset memory ruleset,
        address addrs
    )
        internal
        view
        returns (bool)
    {
        return ruleset.dataHook() != address(0)
            && IJBRulesetDataHook(ruleset.dataHook()).hasMintPermissionFor(projectId, addrs);
    }

    /// @notice The calldata. Preferred to use over `msg.data`.
    /// @return calldata The `msg.data` of this call.
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /// @notice The message's sender. Preferred to use over `msg.sender`.
    /// @return sender The address which sent this call.
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /// @notice The project's upcoming ruleset.
    /// @param projectId The ID of the project to check.
    /// @return The project's upcoming ruleset.
    function _upcomingRulesetOf(uint256 projectId) internal view returns (JBRuleset memory) {
        return RULESETS.upcomingOf(projectId);
    }

    //*********************************************************************//
    // --------------------- external transactions ----------------------- //
    //*********************************************************************//

    /// @notice Add a price feed for a project.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `ADD_PRICE_FEED`.
    /// @param projectId The ID of the project to add the feed for.
    /// @param pricingCurrency The currency the feed's output price is in terms of.
    /// @param unitCurrency The currency being priced by the feed.
    /// @param feed The address of the price feed to add.
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

        JBRuleset memory ruleset = _currentRulesetOf(projectId);

        // Make sure the project's ruleset allows adding price feeds.
        if (!ruleset.allowAddPriceFeed()) revert JBController_AddingPriceFeedNotAllowed();

        PRICES.addPriceFeedFor({
            projectId: projectId,
            pricingCurrency: pricingCurrency,
            unitCurrency: unitCurrency,
            feed: feed
        });
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
        override
    {
        // Enforce permissions.
        _requirePermissionAllowingOverrideFrom({
            account: holder,
            projectId: projectId,
            permissionId: JBPermissionIds.BURN_TOKENS,
            alsoGrantAccessIf: _isTerminalOf(projectId, _msgSender())
        });

        // There must be tokens to burn.
        if (tokenCount == 0) revert JBController_ZeroTokensToBurn();

        emit BurnTokens({holder: holder, projectId: projectId, tokenCount: tokenCount, memo: memo, caller: _msgSender()});

        // Burn the tokens.
        TOKENS.burnFrom({holder: holder, projectId: projectId, count: tokenCount});
    }

    /// @notice Redeem credits to claim tokens into a `beneficiary`'s account.
    /// @dev Can only be called by the credit holder or an address with the holder's permission to `CLAIM_TOKENS`.
    /// @param holder The address to redeem credits from.
    /// @param projectId The ID of the project whose tokens are being claimed.
    /// @param tokenCount The number of tokens to claim.
    /// @param beneficiary The account the claimed tokens will go to.
    function claimTokensFor(
        address holder,
        uint256 projectId,
        uint256 tokenCount,
        address beneficiary
    )
        external
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({account: holder, projectId: projectId, permissionId: JBPermissionIds.CLAIM_TOKENS});

        TOKENS.claimTokensFor({holder: holder, projectId: projectId, count: tokenCount, beneficiary: beneficiary});
    }

    /// @notice Deploys an ERC-20 token for a project. It will be used when claiming tokens (with credits).
    /// @dev Deploys the project's ERC-20 contract.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `DEPLOY_ERC20`.
    /// @param projectId The ID of the project to deploy the ERC-20 for.
    /// @param name The ERC-20's name.
    /// @param symbol The ERC-20's symbol.
    /// @param salt The salt used for ERC-1167 clone deployment. Pass a non-zero salt for deterministic deployment based
    /// on `msg.sender` and the `TOKEN` implementation address.
    /// @return token The address of the token that was deployed.
    function deployERC20For(
        uint256 projectId,
        string calldata name,
        string calldata symbol,
        bytes32 salt
    )
        external
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

        return TOKENS.deployERC20For({projectId: projectId, name: name, symbol: symbol, salt: salt});
    }

    /// @notice When a project receives reserved tokens, if it has a terminal for the token, this is used to pay the
    /// terminal.
    /// @dev Can only be called by this controller.
    /// @param terminal The terminal to pay.
    /// @param projectId The ID of the project being paid.
    /// @param token The token being paid with.
    /// @param splitTokenCount The number of tokens being paid.
    /// @param beneficiary The payment's beneficiary.
    /// @param metadata The pay metadata sent to the terminal.
    function executePayReservedTokenToTerminal(
        IJBTerminal terminal,
        uint256 projectId,
        IJBToken token,
        uint256 splitTokenCount,
        address beneficiary,
        bytes calldata metadata
    )
        external
    {
        // Can only be called by this contract.
        require(msg.sender == address(this));

        // Approve the tokens being paid.
        IERC20(address(token)).forceApprove(address(terminal), splitTokenCount);

        // slither-disable-next-line unused-return
        terminal.pay({
            projectId: projectId,
            token: address(token),
            amount: splitTokenCount,
            beneficiary: beneficiary,
            minReturnedTokens: 0,
            memo: "",
            metadata: metadata
        });

        // Make sure that the terminal received the tokens.
        assert(IERC20(address(token)).allowance(address(this), address(terminal)) == 0);
    }

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
        string calldata memo
    )
        external
        override
        returns (uint256 projectId)
    {
        // Mint the project ERC-721 into the owner's wallet.
        // slither-disable-next-line reentrancy-benign
        projectId = PROJECTS.createFor(owner);

        // If provided, set the project's metadata URI.
        if (bytes(projectUri).length > 0) {
            uriOf[projectId] = projectUri;
        }

        // Set this contract as the project's controller in the directory.
        DIRECTORY.setControllerOf(projectId, IERC165(this));

        // Configure the terminals.
        _configureTerminals(projectId, terminalConfigurations);

        // Queue the rulesets.
        // slither-disable-next-line reentrancy-events
        uint256 rulesetId = _queueRulesets(projectId, rulesetConfigurations);

        emit LaunchProject({
            rulesetId: rulesetId,
            projectId: projectId,
            projectUri: projectUri,
            memo: memo,
            caller: _msgSender()
        });
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
        string calldata memo
    )
        external
        override
        returns (uint256 rulesetId)
    {
        // Make sure there are rulesets being queued.
        if (rulesetConfigurations.length == 0) revert JBController_RulesetsArrayEmpty();

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
            revert JBController_RulesetsAlreadyLaunched();
        }

        // Set this contract as the project's controller in the directory.
        DIRECTORY.setControllerOf(projectId, IERC165(this));

        // Configure the terminals.
        _configureTerminals(projectId, terminalConfigurations);

        // Queue the first ruleset.
        // slither-disable-next-line reentrancy-events
        rulesetId = _queueRulesets(projectId, rulesetConfigurations);

        emit LaunchRulesets({rulesetId: rulesetId, projectId: projectId, memo: memo, caller: _msgSender()});
    }

    /// @notice Migrate a project from this controller to another one.
    /// @dev Can only be called by the directory.
    /// @param projectId The ID of the project to migrate.
    /// @param to The controller to migrate the project to.
    function migrate(uint256 projectId, IERC165 to) external override {
        // Make sure this is being called by the directory.
        if (msg.sender != address(DIRECTORY)) revert JBController_OnlyDirectory(msg.sender, DIRECTORY);

        emit Migrate({projectId: projectId, to: to, caller: msg.sender});

        // Mint any pending reserved tokens before migrating.
        if (pendingReservedTokenBalanceOf[projectId] != 0) {
            _sendReservedTokensToSplitsOf(projectId);
        }

        // Prepare the new controller to receive the project.
        if (to.supportsInterface(type(IJBMigratable).interfaceId)) {
            IJBMigratable(address(to)).receiveMigrationFrom(IERC165(this), projectId);
        }
    }

    /// @notice Add new project tokens or credits to the specified beneficiary's balance. Optionally, reserve a portion
    /// according to the ruleset's reserved percent.
    /// @dev Can only be called by the project's owner, an address with the owner's permission to `MINT_TOKENS`, one of
    /// the project's terminals, or the project's data hook.
    /// @dev If the ruleset's metadata has `allowOwnerMinting` set to `false`, this function can only be called by the
    /// project's terminals or data hook.
    /// @param projectId The ID of the project whose tokens are being minted.
    /// @param tokenCount The number of tokens to mint, including any reserved tokens.
    /// @param beneficiary The address which will receive the (non-reserved) tokens.
    /// @param memo A memo to pass along to the emitted event.
    /// @param useReservedPercent Whether to apply the ruleset's reserved percent.
    /// @return beneficiaryTokenCount The number of tokens minted for the `beneficiary`.
    function mintTokensOf(
        uint256 projectId,
        uint256 tokenCount,
        address beneficiary,
        string calldata memo,
        bool useReservedPercent
    )
        external
        override
        returns (uint256 beneficiaryTokenCount)
    {
        // There should be tokens to mint.
        if (tokenCount == 0) revert JBController_ZeroTokensToMint();

        // Keep a reference to the reserved percent.
        uint256 reservedPercent;

        // Get a reference to the project's ruleset.
        JBRuleset memory ruleset = _currentRulesetOf(projectId);

        // Minting is restricted to: the project's owner, addresses with permission to `MINT_TOKENS`, the project's
        // terminals, and the project's data hook.
        _requirePermissionAllowingOverrideFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.MINT_TOKENS,
            alsoGrantAccessIf: _isTerminalOf(projectId, _msgSender()) || _msgSender() == ruleset.dataHook()
                || _hasDataHookMintPermissionFor(projectId, ruleset, _msgSender())
        });

        // If the message sender is not the project's terminal or data hook, the ruleset must have `allowOwnerMinting`
        // set to `true`.
        if (
            ruleset.id != 0 && !ruleset.allowOwnerMinting() && !_isTerminalOf(projectId, _msgSender())
                && _msgSender() != address(ruleset.dataHook())
                && !_hasDataHookMintPermissionFor(projectId, ruleset, _msgSender())
        ) revert JBController_MintNotAllowedAndNotTerminalOrHook();

        // Determine the reserved percent to use.
        reservedPercent = useReservedPercent ? ruleset.reservedPercent() : 0;

        if (reservedPercent != JBConstants.MAX_RESERVED_PERCENT) {
            // Calculate the number of (non-reserved) tokens that will be minted to the beneficiary.
            beneficiaryTokenCount =
                mulDiv(tokenCount, JBConstants.MAX_RESERVED_PERCENT - reservedPercent, JBConstants.MAX_RESERVED_PERCENT);

            // Mint the tokens.
            // slither-disable-next-line reentrancy-benign,reentrancy-events,unused-return
            TOKENS.mintFor({holder: beneficiary, projectId: projectId, count: beneficiaryTokenCount});
        }

        emit MintTokens({
            beneficiary: beneficiary,
            projectId: projectId,
            tokenCount: tokenCount,
            beneficiaryTokenCount: beneficiaryTokenCount,
            memo: memo,
            reservedPercent: reservedPercent,
            caller: _msgSender()
        });

        // Add any reserved tokens to the pending reserved token balance.
        if (reservedPercent > 0) {
            pendingReservedTokenBalanceOf[projectId] += tokenCount - beneficiaryTokenCount;
        }
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
        override
        returns (uint256 rulesetId)
    {
        // Make sure there are rulesets being queued.
        if (rulesetConfigurations.length == 0) revert JBController_RulesetsArrayEmpty();

        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.QUEUE_RULESETS
        });

        // Queue the rulesets.
        // slither-disable-next-line reentrancy-events
        rulesetId = _queueRulesets(projectId, rulesetConfigurations);

        emit QueueRulesets({rulesetId: rulesetId, projectId: projectId, memo: memo, caller: _msgSender()});
    }

    /// @notice Prepares this controller to receive a project being migrated from another controller.
    /// @dev This controller should not be the project's controller yet.
    /// @param from The controller being migrated from.
    /// @param projectId The ID of the project that will migrate to this controller.
    function receiveMigrationFrom(IERC165 from, uint256 projectId) external override {
        // Keep a reference to the sender.
        address sender = _msgSender();

        // Make sure the sender is the expected source controller.
        if (sender != address(from)) revert JBController_OnlyFromTargetTerminal(sender, address(from));

        // If the sending controller is an `IJBProjectUriRegistry`, copy the project's metadata URI.
        if (
            from.supportsInterface(type(IJBProjectUriRegistry).interfaceId) && DIRECTORY.controllerOf(projectId) == from
        ) {
            uriOf[projectId] = IJBProjectUriRegistry(address(from)).uriOf(projectId);
        }
    }

    /// @notice Sends a project's pending reserved tokens to its reserved token splits.
    /// @dev If the project has no reserved token splits, or if they don't add up to 100%, leftover tokens are sent to
    /// the project's owner.
    /// @param projectId The ID of the project to send reserved tokens for.
    /// @return The amount of reserved tokens minted and sent.
    function sendReservedTokensToSplitsOf(uint256 projectId) external override returns (uint256) {
        return _sendReservedTokensToSplitsOf(projectId);
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
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_SPLIT_GROUPS
        });

        // Set the split groups.
        SPLITS.setSplitGroupsOf({projectId: projectId, rulesetId: rulesetId, splitGroups: splitGroups});
    }

    /// @notice Set a project's token. If the project's token is already set, this will revert.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to `SET_TOKEN`.
    /// @param projectId The ID of the project to set the token of.
    /// @param token The new token's address.
    function setTokenFor(uint256 projectId, IJBToken token) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_TOKEN
        });

        // Get a reference to the current ruleset.
        JBRuleset memory ruleset = _currentRulesetOf(projectId);

        // If there's no current ruleset, get a reference to the upcoming one.
        if (ruleset.id == 0) ruleset = _upcomingRulesetOf(projectId);

        // If owner minting is disabled for the ruleset, the owner cannot change the token.
        if (!ruleset.allowSetCustomToken()) revert JBController_RulesetSetTokenNotAllowed();

        TOKENS.setTokenFor({projectId: projectId, token: token});
    }

    /// @notice Set a project's metadata URI.
    /// @dev This is typically an IPFS hash, optionally with an `ipfs://` prefix.
    /// @dev Can only be called by the project's owner or an address with the owner's permission to
    /// `SET_PROJECT_URI`.
    /// @param projectId The ID of the project to set the metadata URI of.
    /// @param uri The metadata URI to set.
    function setUriOf(uint256 projectId, string calldata uri) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_PROJECT_URI
        });

        // Set the project's metadata URI.
        uriOf[projectId] = uri;

        emit SetUri({projectId: projectId, uri: uri, caller: _msgSender()});
    }

    /// @notice Allows a credit holder to transfer credits to another address.
    /// @dev Can only be called by the credit holder or an address with the holder's permission to `TRANSFER_CREDITS`.
    /// @param holder The address to transfer credits from.
    /// @param projectId The ID of the project whose credits are being transferred.
    /// @param recipient The address to transfer credits to.
    /// @param creditCount The number of credits to transfer.
    function transferCreditsFrom(
        address holder,
        uint256 projectId,
        address recipient,
        uint256 creditCount
    )
        external
        override
    {
        // Enforce permissions.
        _requirePermissionFrom({account: holder, projectId: projectId, permissionId: JBPermissionIds.TRANSFER_CREDITS});

        // Get a reference to the project's ruleset.
        JBRuleset memory ruleset = _currentRulesetOf(projectId);

        // Credit transfers must not be paused.
        if (ruleset.pauseCreditTransfers()) revert JBController_CreditTransfersPaused();

        TOKENS.transferCreditsFrom({holder: holder, projectId: projectId, recipient: recipient, count: creditCount});
    }

    //*********************************************************************//
    // ------------------------ internal functions ----------------------- //
    //*********************************************************************//

    /// @notice Set up a project's terminals.
    /// @param projectId The ID of the project to set up terminals for.
    /// @param terminalConfigs The terminals to set up.
    function _configureTerminals(uint256 projectId, JBTerminalConfig[] calldata terminalConfigs) internal {
        // Initialize an array of terminals to populate.
        IJBTerminal[] memory terminals = new IJBTerminal[](terminalConfigs.length);

        for (uint256 i; i < terminalConfigs.length; i++) {
            // Set the terminal configuration being iterated on.
            JBTerminalConfig memory terminalConfig = terminalConfigs[i];

            // Add the accounting contexts for the specified tokens.
            terminalConfig.terminal.addAccountingContextsFor({
                projectId: projectId,
                accountingContexts: terminalConfig.accountingContextsToAccept
            });

            // Add the terminal.
            terminals[i] = terminalConfig.terminal;
        }

        // Set the terminals in the directory.
        if (terminalConfigs.length > 0) {
            DIRECTORY.setTerminalsOf({projectId: projectId, terminals: terminals});
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
        for (uint256 i; i < rulesetConfigurations.length; i++) {
            // Get a reference to the ruleset config being iterated on.
            JBRulesetConfig memory rulesetConfig = rulesetConfigurations[i];

            // Make sure its reserved percent is valid.
            if (rulesetConfig.metadata.reservedPercent > JBConstants.MAX_RESERVED_PERCENT) {
                revert JBController_InvalidReservedPercent(
                    rulesetConfig.metadata.reservedPercent, JBConstants.MAX_RESERVED_PERCENT
                );
            }

            // Make sure its cash out tax rate is valid.
            if (rulesetConfig.metadata.cashOutTaxRate > JBConstants.MAX_CASH_OUT_TAX_RATE) {
                revert JBController_InvalidCashOutTaxRate(
                    rulesetConfig.metadata.cashOutTaxRate, JBConstants.MAX_CASH_OUT_TAX_RATE
                );
            }

            // Queue its ruleset.
            JBRuleset memory ruleset = RULESETS.queueFor({
                projectId: projectId,
                duration: rulesetConfig.duration,
                weight: rulesetConfig.weight,
                weightCutPercent: rulesetConfig.weightCutPercent,
                approvalHook: rulesetConfig.approvalHook,
                metadata: JBRulesetMetadataResolver.packRulesetMetadata(rulesetConfig.metadata),
                mustStartAtOrAfter: rulesetConfig.mustStartAtOrAfter
            });

            // Set its split groups.
            SPLITS.setSplitGroupsOf({
                projectId: projectId,
                rulesetId: ruleset.id,
                splitGroups: rulesetConfig.splitGroups
            });

            // Set its fund access limits.
            FUND_ACCESS_LIMITS.setFundAccessLimitsFor({
                projectId: projectId,
                rulesetId: ruleset.id,
                fundAccessLimitGroups: rulesetConfig.fundAccessLimitGroups
            });

            // If this is the last configuration being queued, return the ruleset's ID.
            if (i == rulesetConfigurations.length - 1) {
                rulesetId = ruleset.id;
            }
        }
    }

    /// @notice Sends pending reserved tokens to the project's reserved token splits.
    /// @dev If the project has no reserved token splits, or if they don't add up to 100%, leftover tokens are sent to
    /// the project's owner.
    /// @param projectId The ID of the project to send reserved tokens for.
    /// @return tokenCount The amount of reserved tokens minted and sent.
    function _sendReservedTokensToSplitsOf(uint256 projectId) internal returns (uint256 tokenCount) {
        // Get a reference to the number of tokens that need to be minted.
        tokenCount = pendingReservedTokenBalanceOf[projectId];

        // Revert if there are no pending reserved tokens
        if (tokenCount == 0) revert JBController_NoReservedTokens();

        // Get the ruleset to read the reserved percent from.
        JBRuleset memory ruleset = _currentRulesetOf(projectId);

        // Get a reference to the project's owner.
        address owner = PROJECTS.ownerOf(projectId);

        // Reset the pending reserved token balance.
        pendingReservedTokenBalanceOf[projectId] = 0;

        // Mint the tokens to this contract.
        IJBToken token = TOKENS.mintFor({holder: address(this), projectId: projectId, count: tokenCount});

        // Send reserved tokens to splits and get a reference to the amount left after the splits have all been paid.
        uint256 leftoverTokenCount = tokenCount == 0
            ? 0
            : _sendReservedTokensToSplitGroupOf({
                projectId: projectId,
                rulesetId: ruleset.id,
                groupId: JBSplitGroupIds.RESERVED_TOKENS,
                tokenCount: tokenCount,
                token: token
            });

        // Mint any leftover tokens to the project owner.
        if (leftoverTokenCount > 0) {
            _sendTokens({projectId: projectId, tokenCount: leftoverTokenCount, recipient: owner, token: token});
        }

        emit SendReservedTokensToSplits({
            rulesetId: ruleset.id,
            rulesetCycleNumber: ruleset.cycleNumber,
            projectId: projectId,
            owner: owner,
            tokenCount: tokenCount,
            leftoverAmount: leftoverTokenCount,
            caller: _msgSender()
        });
    }

    /// @notice Send project tokens to a split group.
    /// @dev This is used to send reserved tokens to the reserved token split group.
    /// @param projectId The ID of the project the splits belong to.
    /// @param rulesetId The ID of the split group's ruleset.
    /// @param groupId The ID of the split group.
    /// @param tokenCount The number of tokens to send.
    /// @param token The token to send.
    /// @return leftoverTokenCount If the split percents don't add up to 100%, the leftover amount is returned.
    function _sendReservedTokensToSplitGroupOf(
        uint256 projectId,
        uint256 rulesetId,
        uint256 groupId,
        uint256 tokenCount,
        IJBToken token
    )
        internal
        returns (uint256 leftoverTokenCount)
    {
        // Set the leftover amount to the initial amount.
        leftoverTokenCount = tokenCount;

        // Get a reference to the split group.
        JBSplit[] memory splits = SPLITS.splitsOf({projectId: projectId, rulesetId: rulesetId, groupId: groupId});

        // Keep a reference to the number of splits being iterated on.
        uint256 numberOfSplits = splits.length;

        // Send the tokens to the splits.
        for (uint256 i; i < numberOfSplits; i++) {
            // Get a reference to the split being iterated on.
            JBSplit memory split = splits[i];

            // Calculate the amount to send to the split.
            uint256 splitTokenCount = mulDiv(tokenCount, split.percent, JBConstants.SPLITS_TOTAL_PERCENT);

            // Mints tokens for the split if needed.
            if (splitTokenCount > 0) {
                // 1. If the split has a `hook`, call the hook's `processSplitWith` function.
                // 2. Otherwise, if the split has a `projectId`, try to pay the project using the split's `beneficiary`,
                // or the `_msgSender()` if the split has no beneficiary.
                // 3. Otherwise, if the split has a beneficiary, send the tokens to the split's beneficiary.
                // 4. Otherwise, send the tokens to the `_msgSender()`.

                // If the split has a hook, call its `processSplitWith` function.
                if (split.hook != IJBSplitHook(address(0))) {
                    // Send the tokens to the split hook.
                    // slither-disable-next-line reentrancy-events
                    _sendTokens({
                        projectId: projectId,
                        tokenCount: splitTokenCount,
                        recipient: address(split.hook),
                        token: token
                    });

                    // slither-disable-next-line reentrancy-events
                    split.hook.processSplitWith(
                        JBSplitHookContext({
                            token: address(token),
                            amount: splitTokenCount,
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
                        // Get a reference to the receiving project's primary payment terminal for the token.
                        IJBTerminal terminal = token == IJBToken(address(0))
                            ? IJBTerminal(address(0))
                            : DIRECTORY.primaryTerminalOf({projectId: split.projectId, token: address(token)});

                        // If the project doesn't have a token, or if the receiving project doesn't have a terminal
                        // which accepts the token, send the tokens to the beneficiary.
                        if (address(token) == address(0) || address(terminal) == address(0)) {
                            // Mint the tokens to the beneficiary.
                            // slither-disable-next-line reentrancy-events
                            _sendTokens({
                                projectId: projectId,
                                tokenCount: splitTokenCount,
                                recipient: beneficiary,
                                token: token
                            });
                        } else {
                            // Use the `projectId` in the pay metadata.
                            // slither-disable-next-line reentrancy-events
                            bytes memory metadata = bytes(abi.encodePacked(projectId));

                            // Try to fulfill the payment.
                            try this.executePayReservedTokenToTerminal({
                                projectId: split.projectId,
                                terminal: terminal,
                                token: token,
                                splitTokenCount: splitTokenCount,
                                beneficiary: beneficiary,
                                metadata: metadata
                            }) {} catch (bytes memory reason) {
                                emit ReservedDistributionReverted({
                                    projectId: projectId,
                                    split: split,
                                    tokenCount: splitTokenCount,
                                    reason: reason,
                                    caller: _msgSender()
                                });

                                // If it fails, transfer the tokens from this contract to the beneficiary.
                                IERC20(address(token)).safeTransfer(beneficiary, splitTokenCount);
                            }
                        }
                    } else if (beneficiary == address(0xdead)) {
                        // If the split has no project ID, and the beneficiary is 0xdead, burn.
                        TOKENS.burnFrom({holder: address(this), projectId: projectId, count: splitTokenCount});
                    } else {
                        // If the split has no project Id, send to beneficiary.
                        _sendTokens({
                            projectId: projectId,
                            tokenCount: splitTokenCount,
                            recipient: beneficiary,
                            token: token
                        });
                    }
                }

                // Subtract the amount sent from the leftover.
                leftoverTokenCount -= splitTokenCount;
            }

            emit SendReservedTokensToSplit({
                projectId: projectId,
                rulesetId: rulesetId,
                groupId: groupId,
                split: split,
                tokenCount: splitTokenCount,
                caller: _msgSender()
            });
        }
    }

    /// @notice Send tokens from this contract to a recipient.
    /// @param projectId The ID of the project the tokens belong to.
    /// @param tokenCount The number of tokens to send.
    /// @param recipient The address to send the tokens to.
    /// @param token The token to send, if one exists
    function _sendTokens(uint256 projectId, uint256 tokenCount, address recipient, IJBToken token) internal {
        if (token != IJBToken(address(0))) {
            IERC20(address(token)).safeTransfer({to: recipient, value: tokenCount});
        } else {
            TOKENS.transferCreditsFrom({
                holder: address(this),
                projectId: projectId,
                recipient: recipient,
                count: tokenCount
            });
        }
    }
}
