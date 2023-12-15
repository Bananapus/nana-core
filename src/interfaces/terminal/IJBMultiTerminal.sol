// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBProjects} from "../IJBProjects.sol";
import {IJBDirectory} from "../IJBDirectory.sol";
import {IJBTerminalStore} from "../IJBTerminalStore.sol";

import {IJBRedeemTerminal} from "./IJBRedeemTerminal.sol";
import {IJBPayoutTerminal} from "./IJBPayoutTerminal.sol";
import {IJBTerminal} from "./IJBTerminal.sol";
import {IJBFeeTerminal} from "./IJBFeeTerminal.sol";
import {IJBPermitTerminal} from "./IJBPermitTerminal.sol";
import {IJBSplits} from "../IJBSplits.sol";

interface IJBMultiTerminal is IJBTerminal, IJBFeeTerminal, IJBRedeemTerminal, IJBPayoutTerminal, IJBPermitTerminal {
    function STORE() external view returns (IJBTerminalStore);

    function PROJECTS() external view returns (IJBProjects);

    function DIRECTORY() external view returns (IJBDirectory);

    function SPLITS() external view returns (IJBSplits);
}
