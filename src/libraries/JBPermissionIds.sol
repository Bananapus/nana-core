// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library JBPermissionIds {
    uint8 public constant ROOT = 1;
    uint8 public constant QUEUE_RULESETS = 2;
    uint8 public constant REDEEM_TOKENS = 3;
    uint8 public constant MIGRATE_CONTROLLER = 4;
    uint8 public constant MIGRATE_TERMINAL = 5;
    uint8 public constant PROCESS_FEES = 6;
    uint8 public constant SET_PROJECT_METADATA = 7;
    uint8 public constant ISSUE_TOKEN = 8;
    uint8 public constant SET_TOKEN = 9;
    uint8 public constant MINT_TOKENS = 10;
    uint8 public constant BURN_TOKENS = 11;
    uint8 public constant CLAIM_TOKENS = 12;
    uint8 public constant TRANSFER_TOKENS = 13;
    uint8 public constant SET_CONTROLLER = 14;
    uint8 public constant SET_TERMINALS = 15;
    uint8 public constant SET_PRIMARY_TERMINAL = 16;
    uint8 public constant USE_ALLOWANCE = 17;
    uint8 public constant SET_SPLITS = 18;
    uint8 public constant ADD_PRICE_FEED = 19;
    uint8 public constant SET_ACCOUNTING_CONTEXT = 20;
}
