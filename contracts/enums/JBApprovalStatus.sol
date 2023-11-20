// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum JBBallotState {
    Empty,
    Standby,
    Active,
    ApprovalExpected,
    Approved,
    Failed
}
