// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IJBControlled} from "./../interfaces/IJBControlled.sol";
import {IJBDirectory} from "./../interfaces/IJBDirectory.sol";

/// @notice Provides a modifier for contracts with functionality that can only be accessed by a project's controller.
abstract contract JBControlled is IJBControlled {
    //*********************************************************************//
    // --------------------------- custom errors -------------------------- //
    //*********************************************************************//
    error CONTROLLER_UNAUTHORIZED();

    //*********************************************************************//
    // ---------------------------- modifiers ---------------------------- //
    //*********************************************************************//

    /// @notice Only allows the controller of the specified project to proceed.
    /// @param _projectId The ID of the project.
    modifier onlyController(uint256 _projectId) {
        if (address(directory.controllerOf(_projectId)) != msg.sender) {
            revert CONTROLLER_UNAUTHORIZED();
        }
        _;
    }

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override directory;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _directory A contract storing directories of terminals and controllers for each project.
    constructor(IJBDirectory _directory) {
        directory = _directory;
    }
}
