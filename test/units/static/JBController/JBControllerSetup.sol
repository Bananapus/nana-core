// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import /* {*} from */ "../../../helpers/TestBaseWorkflow.sol";

/**
 * @title
 */
contract JBControllerSetup is JBTest {
    // Contracts
    JBRulesets public _rulesets;
    IJBController public _controller;

    // Mocks
    IJBPermissions public permissions = IJBPermissions(makeAddr("permissions"));
    IJBProjects public projects = IJBProjects(makeAddr("projects"));
    IJBDirectory public directory = IJBDirectory(makeAddr("directory"));
    IJBRulesets public rulesets = IJBRulesets(makeAddr("rulesets"));
    IJBTokens public tokens = IJBTokens(makeAddr("tokens"));
    IJBSplits public splits = IJBSplits(makeAddr("splits"));
    IJBFundAccessLimits public fundAccessLimits = IJBFundAccessLimits(makeAddr("limits"));
    address public trustedForwarder = makeAddr("forwarder");

    function controllerSetup() public virtual {
        // Instantiate the contract being tested
        _controller = new JBController(
            permissions, projects, directory, rulesets, tokens, splits, fundAccessLimits, trustedForwarder
        );
    }}