// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBSurplus} from "../libraries/JBSurplus.sol";
import {IJBDirectory} from "../interfaces/IJBDirectory.sol";

/// @notice a UI helper contract for getting the current total reclaimable surplus of a project.
contract JBReclaimableSurplusHelper {
    IJBDirectory public immutable DIRECTORY;

    function currentTotalReclaimableSurplusOf(
        uint256 projectId,
        uint256 decimals,
        uint256 currency
    )
        external
        view
        returns (uint256 surplus)
    {
        return JBSurplus.currentSurplusOf(projectId, DIRECTORY.terminalsOf(projectId), decimals, currency);
    }
}
