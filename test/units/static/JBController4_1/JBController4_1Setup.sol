// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/* 
Contract that deploys a target contract with other mock contracts to satisfy the constructor.
Tests relative to this contract will be dependent on mock calls/emits and stdStorage.
*/
contract JBController4_1Setup is JBTest {
    // Target Contract
    IJBController public _controller;

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBRulesets public rulesets = IJBRulesets(makeAddr("rulesets"));
    IJBTokens public tokens = IJBTokens(makeAddr("tokens"));
    IJBPrices public prices = IJBPrices(makeAddr("prices"));
    IJBSplits public splits = IJBSplits(makeAddr("splits"));
    IJBFundAccessLimits public fundAccessLimits = IJBFundAccessLimits(makeAddr("limits"));
    address public trustedForwarder = makeAddr("forwarder");
    address public omnichainRulesetOperator = makeAddr("omnichainOperator");

    function controllerSetup() public virtual {
        // Instantiate the contract being tested
        _controller = new JBController4_1(
            directory, fundAccessLimits, permissions, prices, projects, rulesets, splits, tokens, omnichainRulesetOperator, trustedForwarder
        );
    }
}
