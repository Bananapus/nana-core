// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBPermissionIds} from "@bananapus/permission-ids/src/JBPermissionIds.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBDirectoryAccessControl} from "./interfaces/IJBDirectoryAccessControl.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBTerminal} from "./interfaces/IJBTerminal.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";

/// @notice Tracks which terminal contracts each project is currently accepting funds through, and which controller
/// contract is managing each project's tokens and rulesets.
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

    /// @notice The controller, which dictates how terminals interact with tokens and rulesets, for a given project ID.
    /// @custom:param projectId The ID of the project to get the controller of.
    mapping(uint256 projectId => IERC165) public override controllerOf;

    /// @notice Addresses allowed to set a project's first controller on their behalf. These addresses/contracts have
    /// been vetted and verified by this contract's owner.
    /// @custom:param addr The address that is either allowed or not.
    mapping(address addr => bool) public override isAllowedToSetFirstController;

    //*********************************************************************//
    // --------------------- internal stored properties ------------------ //
    //*********************************************************************//

    /// @notice For each project ID, the terminals that are currently managing its funds.
    /// @custom:param projectId The ID of the project to get terminals of.
    mapping(uint256 projectId => IJBTerminal[]) internal _terminalsOf;

    /// @notice The project's primary terminal for a given token.
    /// @custom:param projectId The ID of the project to get the primary terminal of.
    /// @custom:param token The token to get the project's primary terminal for.
    mapping(uint256 projectId => mapping(address token => IJBTerminal)) internal _primaryTerminalOf;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice For  given project ID, the terminals which are currently managing that project's funds.
    /// @param projectId The ID of the project to get the terminals of.
    /// @return An array of terminal addresses.
    function terminalsOf(uint256 projectId) external view override returns (IJBTerminal[] memory) {
        return _terminalsOf[projectId];
    }

    /// @notice The primary terminal that a project is using to manage a specified token.
    /// @dev The zero address is returned if a terminal isn't found for the specified token.
    /// @param projectId The ID of the project to get the primary terminal of.
    /// @param token The token the terminal accepts.
    /// @return The address of the primary terminal for the specified project and token.
    function primaryTerminalOf(uint256 projectId, address token) external view override returns (IJBTerminal) {
        // Keep a reference to the primary terminal for the provided project ID and token.
        IJBTerminal primaryTerminal = _primaryTerminalOf[projectId][token];

        // If a primary terminal for the token was specifically set and it's one of the project's terminals, return it.
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

    /// @notice Check if a specified project uses a specified terminal.
    /// @param projectId The ID of the project to check for the terminal.
    /// @param terminal The address of the terminal to check for.
    /// @return A flag indicating whether or not the specified terminal is a terminal of the specified project.
    function isTerminalOf(uint256 projectId, IJBTerminal terminal) public view override returns (bool) {
        // Keep a reference to the number of terminals the project has.
        uint256 numberOfTerminals = _terminalsOf[projectId].length;

        // Loop through and return true if the terminal is contained.
        for (uint256 i; i < numberOfTerminals; i++) {
            // If the terminal being iterated on matches the provided terminal, return true.
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
    /// @dev A controller can be set if:
    /// @dev - The project's ruleset allows setting the controller, and the message sender is the project owner or an
    /// operator with the `SET_CONTROLLER` permission from them.
    /// @dev - OR the message sender is the project's current controller.
    /// @dev - OR an allowedlisted address is setting a controller for a project that doesn't already have a controller.
    /// @param projectId The ID of the project to set the controller of.
    /// @param controller The address of the new controller to set for the project.
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

        // Get a reference to the flag indicating if the project is allowed to set controllers.
        bool allowSetController = address(currentController) == address(0)
            || !currentController.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            ? true
            : IJBDirectoryAccessControl(address(currentController)).setControllerAllowed(projectId);

        // Setting controller is allowed if called from the current controller,
        // OR if the project doesn't have a current controller,
        // OR if the project's ruleset allows setting the controller.
        // Otherwise, revert.
        if (!allowSetController) {
            revert SET_CONTROLLER_NOT_ALLOWED();
        }

        // Set the new controller.
        controllerOf[projectId] = controller;

        emit SetController(projectId, controller, msg.sender);
    }

    /// @notice Set a project's terminals.
    /// @dev Only a project's owner, an operator with the `SET_TERMINALS` permission from the owner, or the project's
    /// controller can set its terminals.
    /// @dev Unless the caller is the project's controller, the project's ruleset must allow setting terminals.
    /// @param projectId The ID of the project to set terminals for.
    /// @param terminals An array of terminal addresses to set for the project.
    function setTerminalsOf(uint256 projectId, IJBTerminal[] calldata terminals) external override {
        // Enforce permissions.
        _requirePermissionAllowingOverrideFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_TERMINALS,
            alsoGrantAccessIf: msg.sender == address(controllerOf[projectId])
        });

        // Keep a reference to the current controller.
        IERC165 controller = controllerOf[projectId];

        // Get a reference to the flag indicating if the project is allowed to set terminals.
        bool allowSetTerminals = !controller.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            || IJBDirectoryAccessControl(address(controller)).setTerminalsAllowed(projectId);

        // Setting terminals must be allowed if not called from the current controller.
        if (msg.sender != address(controllerOf[projectId]) && !allowSetTerminals) {
            revert SET_TERMINALS_NOT_ALLOWED();
        }

        // Set the stored terminals for the project.
        _terminalsOf[projectId] = terminals;

        // Keep a reference to the number of terminals being iterated upon.
        uint256 numberOfTerminals = terminals.length;

        // Make sure duplicates were not added.
        if (numberOfTerminals > 1) {
            for (uint256 i; i < numberOfTerminals; i++) {
                for (uint256 j = i + 1; j < numberOfTerminals; j++) {
                    if (terminals[i] == terminals[j]) revert DUPLICATE_TERMINALS();
                }
            }
        }
        emit SetTerminals(projectId, terminals, msg.sender);
    }

    /// @notice Set a project's primary terminal for a particular token.
    /// @dev The primary terminal is where a token should be routed to by default.
    /// @dev This is useful in case a project has several terminals connected for a particular token.
    /// @dev If setting a newly added terminal and the ruleset doesn't allow new terminals, the caller must be the
    /// current controller.
    /// @param projectId The ID of the project a primary token is being set for.
    /// @param token The token to set the primary terminal for.
    /// @param terminal The terminal to make the primary terminal for the project and token.
    function setPrimaryTerminalOf(uint256 projectId, address token, IJBTerminal terminal) external override {
        // Enforce permissions.
        _requirePermissionFrom({
            account: PROJECTS.ownerOf(projectId),
            projectId: projectId,
            permissionId: JBPermissionIds.SET_PRIMARY_TERMINAL
        });

        // Can't set the primary terminal for a token if the terminal doesn't accept the token.
        if (terminal.accountingContextForTokenOf(projectId, token).token == address(0)) {
            revert TOKEN_NOT_ACCEPTED();
        }

        // Add the terminal to the project if it hasn't been already.
        _addTerminalIfNeeded(projectId, terminal);

        // Store the terminal as the primary terminal for the token.
        _primaryTerminalOf[projectId][token] = terminal;

        emit SetPrimaryTerminal(projectId, token, terminal, msg.sender);
    }

    /// @notice Add an address/contract to the list of trusted addresses which are allowed to set a first controller for
    /// projects.
    /// @dev Only this contract's owner can call this function.
    /// @dev These addresses are known and vetted controllers as well as contracts designed to launch new projects.
    /// @dev A project can set its own controller without being on the allow list.
    /// @dev If you would like an address/contract allowlisted, please reach out to the contract owner.
    /// @param addr The address to allow or not allow.
    /// @param flag Whether the address is allowed or not allowed to set first controllers for projects. Use `true` to
    /// allow and `false` to not allow.
    function setIsAllowedToSetFirstController(address addr, bool flag) external override onlyOwner {
        // Set the flag in the allowlist.
        isAllowedToSetFirstController[addr] = flag;

        emit SetIsAllowedToSetFirstController(addr, flag, msg.sender);
    }

    //*********************************************************************//
    // --------------------- internal helper functions ------------------- //
    //*********************************************************************//

    /// @notice Add a terminal to a project's list of terminals if it hasn't already been added.
    /// @dev Unless the caller is the project's controller, the project's ruleset must allow setting terminals.
    /// @param projectId The ID of the project to add the terminal to.
    /// @param terminal The terminal to add.
    function _addTerminalIfNeeded(uint256 projectId, IJBTerminal terminal) internal {
        // Ensure that the terminal has not already been added.
        if (isTerminalOf(projectId, terminal)) return;

        // Keep a reference to the current controller.
        IERC165 controller = controllerOf[projectId];

        // Get a reference to the flag indicating if the project is allowed to set terminals.
        bool allowSetTerminals = !controller.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            || IJBDirectoryAccessControl(address(controller)).setTerminalsAllowed(projectId);

        // Setting terminals must be allowed if not called from the current controller.
        if (msg.sender != address(controllerOf[projectId]) && !allowSetTerminals) {
            revert SET_TERMINALS_NOT_ALLOWED();
        }

        // Add the new terminal.
        _terminalsOf[projectId].push(terminal);

        emit AddTerminal(projectId, terminal, msg.sender);
    }
}
