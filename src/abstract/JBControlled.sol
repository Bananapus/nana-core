// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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
    /// @param projectId The ID of the project.
    modifier onlyControllerOf(uint256 projectId) {
        if (address(DIRECTORY.controllerOf(projectId)) != msg.sender) {
            revert CONTROLLER_UNAUTHORIZED();
        }
        _;
    }

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The directory of terminals and controllers for projects.
    IJBDirectory public immutable override DIRECTORY;

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param directory A contract storing directories of terminals and controllers for each project.
    constructor(IJBDirectory directory) {
        DIRECTORY = directory;
    }
}
