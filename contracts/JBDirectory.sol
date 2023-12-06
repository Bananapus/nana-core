// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {JBPermissioned} from "./abstract/JBPermissioned.sol";
import {IJBDirectory} from "./interfaces/IJBDirectory.sol";
import {IJBDirectoryAccessControl} from "./interfaces/IJBDirectoryAccessControl.sol";
import {IJBPermissions} from "./interfaces/IJBPermissions.sol";
import {IJBTerminal} from "./interfaces/terminal/IJBTerminal.sol";
import {IJBProjects} from "./interfaces/IJBProjects.sol";
import {JBRulesetMetadataResolver} from "./libraries/JBRulesetMetadataResolver.sol";
import {JBPermissionIds} from "./libraries/JBPermissionIds.sol";
import {JBRuleset} from "./structs/JBRuleset.sol";

/// @notice Tracks which terminal contracts each project is currently accepting funds through, and which controller contract is managing each project's tokens and rulesets.
contract JBDirectory is JBPermissioned, Ownable, IJBDirectory {
    // A library that parses the packed ruleset metadata into a friendlier format.
    using JBRulesetMetadataResolver for JBRuleset;

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error DUPLICATE_TERMINALS();
    error INVALID_PROJECT_ID_IN_DIRECTORY();
    error SET_CONTROLLER_NOT_ALLOWED();
    error SET_TERMINALS_NOT_ALLOWED();
    error TOKEN_NOT_ACCEPTED();

    //*********************************************************************//
    // --------------------- private stored properties ------------------- //
    //*********************************************************************//

    /// @notice For each project ID, the terminals that are currently managing its funds.
    /// @custom:member _projectId The ID of the project to get terminals of.
    mapping(uint256 => IJBTerminal[]) private _terminalsOf;

    /// @notice The project's primary terminal for a given token.
    /// @custom:member _projectId The ID of the project to get the primary terminal of.
    /// @custom:member _token The token to get the project's primary terminal for.
    mapping(uint256 => mapping(address => IJBTerminal)) private _primaryTerminalOf;

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice Mints ERC-721s that represent project ownership and transfers.
    IJBProjects public immutable override projects;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The controller, which dictates how terminals interact with tokens and rulesets, for a given project ID.
    /// @custom:member _projectId The ID of the project to get the controller of.
    mapping(uint256 => IERC165) public override controllerOf;

    /// @notice Addresses allowed to set a project's first controller on their behalf. These addresses/contracts have been vetted and verified by this contract's owner.
    /// @custom:param _address The address that is either allowed or not.
    mapping(address => bool) public override isAllowedToSetFirstController;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice For  given project ID, the terminals which are currently managing that project's funds.
    /// @param _projectId The ID of the project to get the terminals of.
    /// @return An array of terminal addresses.
    function terminalsOf(uint256 _projectId)
        external
        view
        override
        returns (IJBTerminal[] memory)
    {
        return _terminalsOf[_projectId];
    }

    /// @notice The primary terminal that a project is using to manage a specified token.
    /// @dev The zero address is returned if a terminal isn't found for the specified token.
    /// @param _projectId The ID of the project to get the primary terminal of.
    /// @param _token The token the terminal accepts.
    /// @return The address of the primary terminal for the specified project and token.
    function primaryTerminalOf(uint256 _projectId, address _token)
        external
        view
        override
        returns (IJBTerminal)
    {
        // Keep a reference to the primary terminal for the provided project ID and token.
        IJBTerminal _primaryTerminal = _primaryTerminalOf[_projectId][_token];

        // If a primary terminal for the token was specifically set and it's one of the project's terminals, return it.
        if (
            _primaryTerminal != IJBTerminal(address(0))
                && isTerminalOf(_projectId, _primaryTerminal)
        ) return _primaryTerminal;

        // Keep a reference to the number of terminals the project has.
        uint256 _numberOfTerminals = _terminalsOf[_projectId].length;

        // Return the first terminal which accepts the specified token.
        for (uint256 _i; _i < _numberOfTerminals;) {
            // Keep a reference to the terminal being iterated on.
            IJBTerminal _terminal = _terminalsOf[_projectId][_i];

            // If the terminal accepts the specified token, return it.
            if (_terminal.accountingContextForTokenOf(_projectId, _token).token != address(0)) {
                return _terminal;
            }

            unchecked {
                ++_i;
            }
        }

        // Not found.
        return IJBTerminal(address(0));
    }

    //*********************************************************************//
    // -------------------------- public views --------------------------- //
    //*********************************************************************//

    /// @notice Check if a specified project uses a specified terminal.
    /// @param _projectId The ID of the project to check for the terminal.
    /// @param _terminal The address of the terminal to check for.
    /// @return A flag indicating whether or not the specified terminal is a terminal of the specified project.
    function isTerminalOf(uint256 _projectId, IJBTerminal _terminal)
        public
        view
        override
        returns (bool)
    {
        // Keep a reference to the number of terminals the project has.
        uint256 _numberOfTerminals = _terminalsOf[_projectId].length;

        // Loop through and return true if the terminal is contained.
        for (uint256 _i; _i < _numberOfTerminals;) {
            // If the terminal being iterated on matches the provided terminal, return true.
            if (_terminalsOf[_projectId][_i] == _terminal) return true;

            unchecked {
                ++_i;
            }
        }

        // Otherwise, return false.
        return false;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _permissions A contract storing permissions.
    /// @param _projects A contract which mints ERC-721s that represent project ownership and transfers.
    /// @param _owner The address that will own the contract.
    constructor(IJBPermissions _permissions, IJBProjects _projects, address _owner)
        JBPermissioned(_permissions)
        Ownable(_owner)
    {
        projects = _projects;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice Set a project's controller. Controllers manage how terminals interact with tokens and rulesets.
    /// @dev A controller can be set if:
    /// @dev - The project's ruleset allows setting the controller, and the message sender is the project owner or an operator with the `SET_CONTROLLER` permission from them.
    /// @dev - OR the message sender is the project's current controller.
    /// @dev - OR an allowedlisted address is setting a controller for a project that doesn't already have a controller.
    /// @param _projectId The ID of the project to set the controller of.
    /// @param _controller The address of the new controller to set for the project.
    function setControllerOf(uint256 _projectId, IERC165 _controller)
        external
        override
        requirePermissionAllowingOverride(
            projects.ownerOf(_projectId),
            _projectId,
            JBPermissionIds.SET_CONTROLLER,
            (
                isAllowedToSetFirstController[msg.sender]
                    && address(controllerOf[_projectId]) == address(0)
            )
        )
    {
        // The project must exist.
        if (projects.count() < _projectId) revert INVALID_PROJECT_ID_IN_DIRECTORY();

        // Keep a reference to the current controller.
        IERC165 _currentController = controllerOf[_projectId];

        // Get a reference to the flag indicating if the project is allowed to set terminals.
        bool _allowSetController = address(_currentController) == address(0)
            || !_currentController.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            ? true
            : IJBDirectoryAccessControl(address(_currentController)).setControllerAllowed(_projectId);

        // Setting controller is allowed if called from the current controller,
        // OR if the project doesn't have a current controller,
        // OR if the project's ruleset allows setting the controller.
        // Otherwise, revert.
        if (!_allowSetController) {
            revert SET_CONTROLLER_NOT_ALLOWED();
        }

        // Set the new controller.
        controllerOf[_projectId] = _controller;

        emit SetController(_projectId, _controller, msg.sender);
    }

    /// @notice Set a project's terminals.
    /// @dev Only a project's owner, an operator with the `SET_TERMINALS` permission from the owner, or the project's controller can set its terminals.
    /// @dev Unless the caller is the project's controller, the project's ruleset must allow setting terminals.
    /// @param _projectId The ID of the project to set terminals for.
    /// @param _terminals An array of terminal addresses to set for the project.
    function setTerminalsOf(uint256 _projectId, IJBTerminal[] calldata _terminals)
        external
        override
        requirePermissionAllowingOverride(
            projects.ownerOf(_projectId),
            _projectId,
            JBPermissionIds.SET_TERMINALS,
            msg.sender == address(controllerOf[_projectId])
        )
    {
        // Keep a reference to the current controller.
        IERC165 _controller = controllerOf[_projectId];

        // Get a reference to the flag indicating if the project is allowed to set terminals.
        bool _allowSetTerminals = !_controller.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            || IJBDirectoryAccessControl(address(_controller)).setTerminalsAllowed(_projectId);

        // Setting terminals must be allowed if not called from the current controller.
        if (msg.sender != address(controllerOf[_projectId]) && !_allowSetTerminals) {
            revert SET_TERMINALS_NOT_ALLOWED();
        }

        // Set the stored terminals for the project.
        _terminalsOf[_projectId] = _terminals;

        // Keep a reference to the number of terminals being iterated upon.
        uint256 _numberOfTerminals = _terminals.length;

        // Make sure duplicates were not added.
        if (_numberOfTerminals > 1) {
            for (uint256 _i; _i < _numberOfTerminals;) {
                for (uint256 _j = _i + 1; _j < _numberOfTerminals;) {
                    if (_terminals[_i] == _terminals[_j]) revert DUPLICATE_TERMINALS();

                    unchecked {
                        ++_j;
                    }
                }

                unchecked {
                    ++_i;
                }
            }
        }
        emit SetTerminals(_projectId, _terminals, msg.sender);
    }

    /// @notice Set a project's primary terminal for a particular token.
    /// @dev The primary terminal is where a token should be routed to by default.
    /// @dev This is useful in case a project has several terminals connected for a particular token.
    /// @dev If setting a newly added terminal and the ruleset doesn't allow new terminals, the caller must be the current controller.
    /// @param _projectId The ID of the project a primary token is being set for.
    /// @param _token The token to set the primary terminal for.
    /// @param _terminal The terminal to make the primary terminal for the project and token.
    function setPrimaryTerminalOf(uint256 _projectId, address _token, IJBTerminal _terminal)
        external
        override
        requirePermission(
            projects.ownerOf(_projectId),
            _projectId,
            JBPermissionIds.SET_PRIMARY_TERMINAL
        )
    {
        // Can't set the primary terminal for a token if the terminal doesn't accept the token.
        if (_terminal.accountingContextForTokenOf(_projectId, _token).token == address(0)) {
            revert TOKEN_NOT_ACCEPTED();
        }

        // Add the terminal to the project if it hasn't been already.
        _addTerminalIfNeeded(_projectId, _terminal);

        // Store the terminal as the primary terminal for the token.
        _primaryTerminalOf[_projectId][_token] = _terminal;

        emit SetPrimaryTerminal(_projectId, _token, _terminal, msg.sender);
    }

    /// @notice Add an address/contract to the list of trusted addresses which are allowed to set a first controller for projects.
    /// @dev Only this contract's owner can call this function.
    /// @dev These addresses are known and vetted controllers as well as contracts designed to launch new projects.
    /// @dev A project can set its own controller without being on the allow list.
    /// @dev If you would like an address/contract allowlisted, please reach out to the contract owner.
    /// @param _address The address to allow or not allow.
    /// @param _flag Whether the address is allowed or not allowed to set first controllers for projects. Use `true` to allow and `false` to not allow.
    function setIsAllowedToSetFirstController(address _address, bool _flag)
        external
        override
        onlyOwner
    {
        // Set the flag in the allowlist.
        isAllowedToSetFirstController[_address] = _flag;

        emit SetIsAllowedToSetFirstController(_address, _flag, msg.sender);
    }

    //*********************************************************************//
    // --------------------- private helper functions -------------------- //
    //*********************************************************************//

    /// @notice Add a terminal to a project's list of terminals if it hasn't already been added.
    /// @dev Unless the caller is the project's controller, the project's ruleset must allow setting terminals.
    /// @param _projectId The ID of the project to add the terminal to.
    /// @param _terminal The terminal to add.
    function _addTerminalIfNeeded(uint256 _projectId, IJBTerminal _terminal) private {
        // Ensure that the terminal has not already been added.
        if (isTerminalOf(_projectId, _terminal)) return;

        // Keep a reference to the current controller.
        IERC165 _controller = controllerOf[_projectId];

        // Get a reference to the flag indicating if the project is allowed to set terminals.
        bool _allowSetTerminals = !_controller.supportsInterface(type(IJBDirectoryAccessControl).interfaceId)
            || IJBDirectoryAccessControl(address(_controller)).setTerminalsAllowed(_projectId);

        // Setting terminals must be allowed if not called from the current controller.
        if (msg.sender != address(controllerOf[_projectId]) && !_allowSetTerminals) {
            revert SET_TERMINALS_NOT_ALLOWED();
        }

        // Add the new terminal.
        _terminalsOf[_projectId].push(_terminal);

        emit AddTerminal(_projectId, _terminal, msg.sender);
    }
}
