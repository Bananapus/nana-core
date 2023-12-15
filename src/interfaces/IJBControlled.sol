// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "./IJBDirectory.sol";

interface IJBControlled {
    function DIRECTORY() external view returns (IJBDirectory);
}
