// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBDirectory} from "./IJBDirectory.sol";
import {IJBFeeTerminal} from "./IJBFeeTerminal.sol";
import {IJBPayoutTerminal} from "./IJBPayoutTerminal.sol";
import {IJBPermitTerminal} from "./IJBPermitTerminal.sol";
import {IJBProjects} from "./IJBProjects.sol";
import {IJBRedeemTerminal} from "./IJBRedeemTerminal.sol";
import {IJBRulesets} from "./IJBRulesets.sol";
import {IJBSplits} from "./IJBSplits.sol";
import {IJBTerminal} from "./IJBTerminal.sol";
import {IJBTerminalStore} from "./IJBTerminalStore.sol";
import {IJBTokens} from "./IJBTokens.sol";

interface IJBMultiTerminal is IJBTerminal, IJBFeeTerminal, IJBRedeemTerminal, IJBPayoutTerminal, IJBPermitTerminal {
    function DIRECTORY() external view returns (IJBDirectory);
    function PROJECTS() external view returns (IJBProjects);
    function RULESETS() external view returns (IJBRulesets);
    function SPLITS() external view returns (IJBSplits);
    function STORE() external view returns (IJBTerminalStore);
    function TOKENS() external view returns (IJBTokens);
}
