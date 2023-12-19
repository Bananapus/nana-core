// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IJBTerminal} from "./../interfaces/terminal/IJBTerminal.sol";

/// @custom:member terminal The terminal to configure.
/// @custom:member acceptedTokens The tokens to accept from the terminal.
struct JBTerminalConfig {
    IJBTerminal terminal;
    address[] tokensToAccept;
}
