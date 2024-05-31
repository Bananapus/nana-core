// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

interface IJBMigratable is IERC165 {
    event Migrate(uint256 indexed projectId, IERC165 to, address caller);

    function receiveMigrationFrom(IERC165 from, uint256 projectId) external;
    function migrate(uint256 projectId, IERC165 to) external;
}
