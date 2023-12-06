// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./IJBTerminal.sol";
import {IPermit2} from "@permit2/src/src/interfaces/IPermit2.sol";

interface IJBPermitTerminal is IJBTerminal {
    function PERMIT2() external returns (IPermit2);
}
