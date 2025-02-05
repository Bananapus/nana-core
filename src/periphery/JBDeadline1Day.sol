// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {JBDeadline} from "../JBDeadline.sol";

contract JBDeadline1Day is JBDeadline {
    constructor() JBDeadline(1 days) {}
}
