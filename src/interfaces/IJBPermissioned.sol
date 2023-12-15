// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBPermissions} from "./IJBPermissions.sol";

interface IJBPermissioned {
    function PERMISSIONS() external view returns (IJBPermissions);
}
