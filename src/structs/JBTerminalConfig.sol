// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {JBAccountingContext} from "./JBAccountingContext.sol";
import {IJBTerminal} from "./../interfaces/IJBTerminal.sol";

/// @custom:member terminal The terminal to configure.
/// @custom:member accountingContextsToAccept The accounting contexts to accept from the terminal.
struct JBTerminalConfig {
    IJBTerminal terminal;
    JBAccountingContext[] accountingContextsToAccept;
}
