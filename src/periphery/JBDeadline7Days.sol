// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBDeadline} from "../JBDeadline.sol";

contract JBDeadline7Days is JBDeadline {
    constructor() JBDeadline(7 days) {}
}
