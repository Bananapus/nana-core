// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBController} from "./IJBController.sol";

interface IJBController4_1 is IJBController {
    event DeployERC20(
        uint256 indexed projectId, address indexed deployer, bytes32 salt, bytes32 saltHash, address caller
    );

    function OMNICHAIN_RULESET_OPERATOR() external view returns (address);
}
