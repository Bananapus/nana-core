// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBDirectoryAccessControl} from "./interfaces/IJBDirectoryAccessControl.sol";
import {IJBMigratable} from "./interfaces/IJBMigratable.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBTerminal} from "./interfaces/IJBTerminal.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";

/// @notice `JBDirectory` tracks the terminals and the controller used by each project.
/// @dev Tracks which `IJBTerminal`s each project is currently accepting funds through, and which `IJBController` is
/// managing each project's tokens and rulesets.
contract JBDirectory is JBPermissioned, Ownable, IJBDirectory {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error DUPLICATE_TERMINALS();
    error INVALID_PROJECT_ID_IN_DIRECTORY();
    error SET_CONTROLLER_NOT_ALLOWED();
    error SET_TERMINALS_NOT_ALLOWED();
    error TOKEN_NOT_ACCEPTED();

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice Mints ERC-721s that represent project ownership and transfers.
    IJBProjects public immutable override PROJECTS;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The specified project's controller, which dictates how its terminals interact with its tokens and
    /// rulesets.
    /// @custom:param projectId The ID of the project to get the controller of.
    mapping(uint256 projectId => IERC165) public override controllerOf;

    /// @notice Whether the specified address is allowed to set a project's first controller on their behalf.
    /// @dev These addresses/contracts have been vetted by this contract's owner.
    /// @custom:param addr The address to check.
    mapping(address addr => bool) public override isAllowedToSetFirstController;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice The specified project's terminals.
    /// @custom:param projectId The ID of the project to get the terminals of.
    mapping(uint256 projectId => IJBTerminal[]) internal _terminalsOf;

    /// @notice The primary terminal that a project uses for the specified token.
    /// @custom:param projectId The ID of the project to get the primary terminal of.
    /// @custom:param token The token that the terminal accepts.
    mapping(uint256 projectId => mapping(address token => IJBTerminal)) internal _primaryTerminalOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice The specified project's terminals.
    /// @param projectId The ID of the project to get the terminals of.
    /// @return An array of the project's terminal addresses.
    function terminalsOf(uint256 projectId) external view override returns (IJBTerminal[] memory) {
        return _terminalsOf[projectId];
    }

    /// @notice The primary terminal that a project uses for the specified token.
    /// @dev Returns the first terminal that accepts the token if the project hasn't explicitly set a primary terminal
    /// for it.
    /// @dev Returns the zero address if no terminal accepts the token.
    /// @param projectId The ID of the project to get the primary terminal of.
    /// @param token The token that the terminal accepts.
    /// @return The primary terminal's address.
    function primaryTerminalOf(uint256 projectId, address token) external view override returns (IJBTerminal) {
        // Keep a reference to the primary terminal for the provided project ID and token.
        IJBTerminal primaryTerminal = _primaryTerminalOf[projectId][token];

        // If a primary terminal for the token was explicitly set and it's one of the project's terminals, return it.
        if (primaryTerminal != IJBTerminal(address(0)) && isTerminalOf(projectId, primaryTerminal)) {
            return primaryTerminal;
        }

        // Keep a reference to the number of terminals the project has.
        uint256 numberOfTerminals = _terminalsOf[projectId].length;

        // Return the first terminal which accepts the specified token.
        for (uint256 i; i < numberOfTerminals; i++) {
            // Keep a reference to the terminal being iterated on.
            IJBTerminal terminal = _terminalsOf[projectId][i];

            // If the terminal accepts the specified token, return it.
            if (terminal.accountingContextForTokenOf(projectId, token).token != address(0)) {
                return terminal;
            }
        }

        // Not found.
        return IJBTerminal(address(0));
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Check if a project uses a specific terminal.
    /// @param projectId The ID of the project to check.
    /// @param terminal The terminal to check for.
    /// @return A flag indicating whether the project uses the terminal.
    function isTerminalOf(uint256 projectId, IJBTerminal terminal) public view override returns (bool) {
        // Keep a reference to the number of terminals the project has.
        uint256 numberOfTerminals = _terminalsOf[projectId].length;

        // Loop through and return true if the terminal is found.
        for (uint256 i; i < numberOfTerminals; i++) {
            if (_terminalsOf[projectId][i] == terminal) return true;
        }

        // Otherwise, return false.
        return false;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param permissions A contract storing permissions.
    /// @param projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param owner The address that will own the contract.
    constructor(
        IJBPermissions permissions,
        IJBProjects projects,
        address owner
    )
        JBPermissioned(permissions)
        Ownable(owner)
    {
        PROJECTS = projects;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Set a project's controller. Controllers manage how terminals interact with tokens and rulesets.
    /// @dev Can only be called if:
    /// - The ruleset's metadata has `allowSetController` enabled, and the message's sender is the project's owner or an
    /// address with the owner's permission to `SET_CONTROLLER`.
    /// - OR the message's sender is the project's current controller.
    /// - OR an address which `isAllowedToSetFirstController` is setting a project's first controller.
    /// @param projectId The ID of the project whose controller is being set.
    /// @param controller The address of the controller to set.
    function setControllerOf(uint256 projectId, IERC165 controller) external override {
        // Enforce permissions.
        _requirePermissionAllowingOverrideFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_CONTROLLER,
            alsoGrantAccessIf: (isAllowedToSetFirstController[msg.sender] && address(controllerOf[projectId]) == address(0))
        });
        // The project must exist.
        if (PROJECTS.count() < projectId) revert INVALID_PROJECT_ID_IN_DIRECTORY();

        // Keep a reference to the current controller.
        IERC165 currentController = controllerOf[projectId];

        // Get a reference to a flag indicating whether the project is allowed to set its controller.
        // Setting the controller is allowed if the project doesn't have a controller,
        // OR if the caller is the current controller,
        // OR if the project's ruleset allows setting the controller.
        bool allowSetController = address(currentController) == address(0)
            || !currentController.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            ? true
            : IJBDirectoryAccessControl(address(currentController)).setControllerAllowed(projectId);

        // If setting the controller is not allowed, revert.
        if (!allowSetController) {
            revert SET_CONTROLLER_NOT_ALLOWED();
        }

        // Migrate if needed.
        if (
            address(currentController) != address(0)
                && currentController.supportsInterface(type(IJBMigratable).interfaceId)
        ) {
            IJBMigratable(address(currentController)).migrate(projectId, controller);
        }

        // Set the new controller.
        controllerOf[projectId] = controller;

        emit SetController(projectId, controller, msg.sender);
    }

    /// @notice Set a project's terminals.
    /// @dev Can only be called by the project's owner, an address with the owner's permission to `SET_TERMINALS`, or
    /// the project's controller.
    /// @dev Unless the caller is the project's controller, the project's ruleset must allow setting terminals.
    /// @param projectId The ID of the project whose terminals are being set.
    /// @param terminals An array of terminal addresses to set for the project.
    function setTerminalsOf(uint256 projectId, IJBTerminal[] calldata terminals) external override {
        // Enforce permissions.
        _requirePermissionAllowingOverrideFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_TERMINALS,
            alsoGrantAccessIf: msg.sender == address(controllerOf[projectId])
        });

        // Keep a reference to the project's controller.
        IERC165 controller = controllerOf[projectId];

        // Get a reference to the flag indicating whether the project is allowed to set its terminals.
        bool allowSetTerminals = !controller.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            || IJBDirectoryAccessControl(address(controller)).setTerminalsAllowed(projectId);

        // If the caller is not the project's controller, the project's ruleset must allow setting terminals.
        if (msg.sender != address(controllerOf[projectId]) && !allowSetTerminals) {
            revert SET_TERMINALS_NOT_ALLOWED();
        }

        // Set the stored terminals for the project.
        _terminalsOf[projectId] = terminals;

        // Keep a reference to the number of terminals being iterated upon.
        uint256 numberOfTerminals = terminals.length;

        // If there are any duplicates, revert.
        if (numberOfTerminals > 1) {
            for (uint256 i; i < numberOfTerminals; i++) {
                for (uint256 j = i + 1; j < numberOfTerminals; j++) {
                    if (terminals[i] == terminals[j]) revert DUPLICATE_TERMINALS();
                }
            }
        }
        emit SetTerminals(projectId, terminals, msg.sender);
    }

    /// @notice Set a project's primary terminal for a token.
    /// @dev The primary terminal for a token is where payments in that token are routed to by default.
    /// @dev This is useful in cases where a project has multiple terminals which accept the same token.
    /// @dev Can only be called by the project's owner, or an address with the owner's permission to
    /// `SET_PRIMARY_TERMINAL`.
    /// @param projectId The ID of the project whose primary terminal is being set.
    /// @param token The token to set the primary terminal for.
    /// @param terminal The terminal being set as the primary terminal.
    function setPrimaryTerminalOf(uint256 projectId, address token, IJBTerminal terminal) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_PRIMARY_TERMINAL
        });

        // If the terminal doesn't accept the token, revert.
        if (terminal.accountingContextForTokenOf(projectId, token).token == address(0)) {
            revert TOKEN_NOT_ACCEPTED();
        }

        // If the terminal hasn't already been added to the project, add it.
        _addTerminalIfNeeded(projectId, terminal);

        // Store the terminal as the project's primary terminal for the token.
        _primaryTerminalOf[projectId][token] = terminal;

        emit SetPrimaryTerminal(projectId, token, terminal, msg.sender);
    }

    /// @notice Add or remove an address/contract from a list of trusted addresses which are allowed to set a first
    /// controller for projects.
    /// @dev Only this contract's owner can call this function.
    /// @dev These addresses are vetted controllers as well as contracts designed to launch new projects.
    /// @dev A project can set its own controller without being on this list.
    /// @dev If you would like to add an address/contract to this list, please reach out to this contract's owner.
    /// @param addr The address to allow or not allow.
    /// @param flag Whether the address is allowed to set first controllers for projects. Use `true` to allow and
    /// `false` to not allow.
    function setIsAllowedToSetFirstController(address addr, bool flag) external override onlyOwner {
        // Set the flag in the allowlist.
        isAllowedToSetFirstController[addr] = flag;

        emit SetIsAllowedToSetFirstController(addr, flag, msg.sender);
    }

    //*********************************************************************//
    // --------------------- internal helper functions ------------------- //
    //*********************************************************************//

    /// @notice If a terminal hasn't already been added to a project's list of terminals, add it.
    /// @dev Unless the caller is the project's controller, the project's ruleset must have `allowSetTerminals` set to
    /// `true`.
    /// @param projectId The ID of the project to add the terminal to.
    /// @param terminal The terminal to add.
    function _addTerminalIfNeeded(uint256 projectId, IJBTerminal terminal) internal {
        // Ensure that the terminal has not already been added.
        if (isTerminalOf(projectId, terminal)) return;

        // Keep a reference to the current controller.
        IERC165 controller = controllerOf[projectId];

        // Get a reference to a flag indicating whether the project is allowed to set its terminals.
        bool allowSetTerminals = !controller.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            || IJBDirectoryAccessControl(address(controller)).setTerminalsAllowed(projectId);

        // If the caller is not the project's controller, the project's ruleset must allow setting terminals.
        if (msg.sender != address(controllerOf[projectId]) && !allowSetTerminals) {
            revert SET_TERMINALS_NOT_ALLOWED();
        }

        // Add the new terminal.
        _terminalsOf[projectId].push(terminal);

        emit AddTerminal(projectId, terminal, msg.sender);
    }
}
