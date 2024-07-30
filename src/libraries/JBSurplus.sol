// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IJBTerminal} from "../interfaces/IJBTerminal.sol";

/// @notice Surplus calculations.
library JBSurplus {
    /// @notice Gets the total current surplus amount across all of a project's terminals.
    /// @dev This amount changes as the value of the balances changes in relation to the currency being used to measure
    /// the project's payout limits.
    /// @param projectId The ID of the project to get the total surplus for.
    /// @param terminals The terminals to look for surplus within.
    /// @param decimals The number of decimals that the fixed point surplus result should include.
    /// @param currency The currency that the surplus result should be in terms of.
    /// @return surplus The total surplus of a project's funds in terms of `currency`, as a fixed point number with the
    /// specified number of decimals.
    function currentSurplusOf(
        uint256 projectId,
        IJBTerminal[] memory terminals,
        uint256 decimals,
        uint256 currency
    )
        internal
        view
        returns (uint256 surplus)
    {
        // Keep a reference to the number of termainls.
        uint256 numberOfTerminals = terminals.length;

        // Add the current surplus for each terminal.
        for (uint256 i; i < numberOfTerminals; i++) {
            surplus += terminals[i].currentSurplusOf(projectId, decimals, currency);
        }
    }
}
